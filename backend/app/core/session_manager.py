import asyncio
import json
import logging
import uuid
from datetime import datetime, timedelta, timezone

import asyncpg
from redis import asyncio as redis_async

from app.core.config import settings

logger = logging.getLogger("uvicorn.error")


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class SessionManager:
    def __init__(self) -> None:
        self._postgres_dsn = settings.postgres_dsn
        self._redis_url = settings.redis_url
        self._timeout_seconds = max(1, settings.auto_logout_seconds)
        self._retention_seconds = max(0, settings.session_retention_seconds)
        self._pool_min_size = max(1, settings.postgres_pool_min_size)
        self._pool_max_size = max(
            self._pool_min_size,
            settings.postgres_pool_max_size,
        )
        self._pool: asyncpg.Pool | None = None
        self._redis: redis_async.Redis | None = None

    def _redis_key(self, session_id: str) -> str:
        return f"session:{session_id}"

    def _require_ready(self) -> tuple[asyncpg.Pool, redis_async.Redis]:
        if self._pool is None or self._redis is None:
            raise RuntimeError("SessionManager is not initialized")
        return self._pool, self._redis

    async def initialize(self) -> None:
        last_error: Exception | None = None
        for attempt in range(1, 6):
            try:
                if self._pool is None:
                    self._pool = await asyncpg.create_pool(
                        dsn=self._postgres_dsn,
                        min_size=self._pool_min_size,
                        max_size=self._pool_max_size,
                    )
                if self._redis is None:
                    self._redis = redis_async.from_url(
                        self._redis_url,
                        decode_responses=True,
                    )

                pool, redis = self._require_ready()
                async with pool.acquire() as conn:
                    await conn.execute(
                        """
                        CREATE TABLE IF NOT EXISTS user_sessions (
                          session_id TEXT PRIMARY KEY,
                          username TEXT NOT NULL,
                          created_at TIMESTAMPTZ NOT NULL,
                          last_activity_at TIMESTAMPTZ NOT NULL,
                          expires_at TIMESTAMPTZ NOT NULL,
                          revoked_at TIMESTAMPTZ NULL
                        )
                        """
                    )
                    await conn.execute(
                        """
                        CREATE TABLE IF NOT EXISTS user_activity_logs (
                          id BIGSERIAL PRIMARY KEY,
                          occurred_at TIMESTAMPTZ NOT NULL,
                          username TEXT NOT NULL,
                          session_id TEXT NOT NULL,
                          method TEXT NOT NULL,
                          path TEXT NOT NULL,
                          status_code INTEGER NOT NULL,
                          duration_ms INTEGER NOT NULL,
                          client_ip TEXT NOT NULL,
                          user_agent TEXT NOT NULL
                        )
                        """
                    )
                await redis.ping()
                return
            except Exception as exc:  # pragma: no cover - startup retry path
                last_error = exc
                logger.warning(
                    "Session backend init failed (%s/5): %s",
                    attempt,
                    exc,
                )
                await asyncio.sleep(1.0)

        raise RuntimeError(f"Failed to initialize session backend: {last_error}")

    async def close(self) -> None:
        if self._redis is not None:
            await self._redis.aclose()
            self._redis = None
        if self._pool is not None:
            await self._pool.close()
            self._pool = None

    async def create_session(self, username: str) -> str:
        pool, redis = self._require_ready()
        now = _utcnow()
        expires_at = now + timedelta(seconds=self._timeout_seconds)
        session_id = str(uuid.uuid4())

        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO user_sessions (
                  session_id, username, created_at, last_activity_at, expires_at
                )
                VALUES ($1, $2, $3, $4, $5)
                """,
                session_id,
                username,
                now,
                now,
                expires_at,
            )

        payload = json.dumps({"username": username})
        await redis.set(self._redis_key(session_id), payload, ex=self._timeout_seconds)
        return session_id

    async def validate_and_touch(self, session_id: str) -> str | None:
        pool, redis = self._require_ready()
        key = self._redis_key(session_id)
        raw = await redis.get(key)
        if not raw:
            return None

        try:
            cache = json.loads(raw)
            cached_username = str(cache.get("username") or "").strip()
        except (TypeError, ValueError, json.JSONDecodeError):
            await redis.delete(key)
            return None
        if not cached_username:
            await redis.delete(key)
            return None

        now = _utcnow()
        expires_at = now + timedelta(seconds=self._timeout_seconds)
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT username, revoked_at
                FROM user_sessions
                WHERE session_id = $1
                """,
                session_id,
            )
            if row is None:
                await redis.delete(key)
                return None
            if row["revoked_at"] is not None or row["username"] != cached_username:
                await redis.delete(key)
                return None

            await conn.execute(
                """
                UPDATE user_sessions
                SET last_activity_at = $1,
                    expires_at = $2
                WHERE session_id = $3
                """,
                now,
                expires_at,
                session_id,
            )

        await redis.expire(key, self._timeout_seconds)
        return cached_username

    async def revoke_session(self, session_id: str) -> None:
        pool, redis = self._require_ready()
        now = _utcnow()
        async with pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE user_sessions
                SET revoked_at = $1
                WHERE session_id = $2
                """,
                now,
                session_id,
            )
        await redis.delete(self._redis_key(session_id))

    async def delete_expired_or_revoked_sessions(self) -> int:
        pool, _ = self._require_ready()
        now = _utcnow()
        cutoff = now - timedelta(seconds=self._retention_seconds)
        total_deleted = 0
        async with pool.acquire() as conn:
            session_result = await conn.execute(
                """
                DELETE FROM user_sessions
                WHERE (revoked_at IS NOT NULL AND revoked_at <= $1)
                   OR (revoked_at IS NULL AND expires_at <= $1)
                """,
                cutoff,
            )
            activity_result = await conn.execute(
                """
                DELETE FROM user_activity_logs
                WHERE occurred_at <= $1
                """,
                cutoff,
            )

        # asyncpg returns: "DELETE <count>"
        for result in (session_result, activity_result):
            try:
                total_deleted += int(result.split(" ", 1)[1])
            except (IndexError, ValueError):
                continue
        return total_deleted

    async def record_activity(
        self,
        *,
        username: str,
        session_id: str,
        method: str,
        path: str,
        status_code: int,
        duration_ms: int,
        client_ip: str,
        user_agent: str,
    ) -> None:
        pool, _ = self._require_ready()
        occurred_at = _utcnow()
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO user_activity_logs (
                  occurred_at,
                  username,
                  session_id,
                  method,
                  path,
                  status_code,
                  duration_ms,
                  client_ip,
                  user_agent
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                """,
                occurred_at,
                username,
                session_id,
                method,
                path,
                status_code,
                duration_ms,
                client_ip,
                user_agent,
            )
