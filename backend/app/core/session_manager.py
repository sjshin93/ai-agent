import asyncio
import json
import logging
import uuid
from datetime import date, datetime, timedelta, timezone

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
                          user_id TEXT NOT NULL,
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
                          user_id TEXT NOT NULL,
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
                    await conn.execute(
                        """
                        CREATE TABLE IF NOT EXISTS users (
                          user_id TEXT PRIMARY KEY,
                          provider TEXT NOT NULL,
                          provider_user_id TEXT NOT NULL,
                          role TEXT NOT NULL,
                          nickname TEXT NOT NULL,
                          created_at TIMESTAMPTZ NOT NULL,
                          updated_at TIMESTAMPTZ NOT NULL,
                          last_login_at TIMESTAMPTZ NOT NULL
                        )
                        """
                    )
                    await conn.execute(
                        """
                        CREATE TABLE IF NOT EXISTS llm_chat_logs (
                          id BIGSERIAL PRIMARY KEY,
                          occurred_at TIMESTAMPTZ NOT NULL,
                          user_id TEXT NOT NULL,
                          model TEXT NOT NULL,
                          prompt TEXT NOT NULL,
                          response TEXT NOT NULL
                        )
                        """
                    )
                    await conn.execute(
                        """
                        CREATE INDEX IF NOT EXISTS llm_chat_logs_user_time_idx
                        ON llm_chat_logs(user_id, occurred_at DESC)
                        """
                    )
                    await conn.execute(
                        """
                        CREATE TABLE IF NOT EXISTS diary_entries (
                          id UUID PRIMARY KEY,
                          person_id TEXT NOT NULL,
                          storage_path TEXT NOT NULL,
                          created_at TIMESTAMPTZ NOT NULL,
                          sha256 TEXT NOT NULL,
                          event_date DATE NOT NULL,
                          emotion_label TEXT,
                          event_text TEXT,
                          feeling_text TEXT,
                          reason_text TEXT,
                          next_action_text TEXT
                        )
                        """
                    )
                    await conn.execute(
                        """
                        CREATE UNIQUE INDEX IF NOT EXISTS diary_entries_person_sha256_idx
                        ON diary_entries(person_id, sha256)
                        """
                    )
                    await conn.execute(
                        """
                        CREATE TABLE IF NOT EXISTS voice_archives (
                          id UUID PRIMARY KEY,
                          person_id TEXT NOT NULL,
                          file_name TEXT NOT NULL,
                          file_ext TEXT NOT NULL,
                          storage_key TEXT NOT NULL,
                          created_at TIMESTAMP NOT NULL
                            DEFAULT timezone('Asia/Seoul', now()),
                          sha256 TEXT NOT NULL,
                          captured_at TIMESTAMP NULL,
                          tags TEXT NOT NULL DEFAULT '',
                          emotion TEXT NULL,
                          reference_text TEXT NULL,
                          stt_text TEXT NULL
                        )
                        """
                    )
                    await conn.execute(
                        """
                        CREATE UNIQUE INDEX IF NOT EXISTS voice_archives_storage_key_uniq
                        ON voice_archives(storage_key)
                        """
                    )
                    await conn.execute(
                        """
                        CREATE UNIQUE INDEX IF NOT EXISTS voice_archives_sha256_uniq
                        ON voice_archives(sha256)
                        """
                    )
                    await conn.execute(
                        """
                        CREATE INDEX IF NOT EXISTS voice_archives_person_created_idx
                        ON voice_archives(person_id, created_at DESC)
                        """
                    )
                    await conn.execute(
                        """
                        CREATE INDEX IF NOT EXISTS voice_archives_person_captured_idx
                        ON voice_archives(person_id, captured_at DESC)
                        """
                    )
                    await conn.execute(
                        """
                        CREATE UNIQUE INDEX IF NOT EXISTS users_provider_provider_user_id_uniq
                        ON users(provider, provider_user_id)
                        """
                    )
                    # Backward compatibility for previously created tables.
                    await conn.execute(
                        """
                        ALTER TABLE users
                        ADD COLUMN IF NOT EXISTS role TEXT
                        """
                    )
                    await conn.execute(
                        """
                        UPDATE users
                        SET role = 'user'
                        WHERE role IS NULL OR role = ''
                        """
                    )
                    await conn.execute(
                        """
                        ALTER TABLE users
                        ALTER COLUMN role SET NOT NULL
                        """
                    )
                    await conn.execute(
                        """
                        ALTER TABLE user_sessions
                        ADD COLUMN IF NOT EXISTS user_id TEXT
                        """
                    )
                    await conn.execute(
                        """
                        DO $$
                        BEGIN
                          IF EXISTS (
                            SELECT 1
                            FROM information_schema.columns
                            WHERE table_name = 'user_sessions'
                              AND column_name = 'username'
                          ) THEN
                            UPDATE user_sessions
                            SET user_id = username
                            WHERE user_id IS NULL OR user_id = '';
                          END IF;
                        END $$;
                        """
                    )
                    await conn.execute(
                        """
                        ALTER TABLE user_sessions
                        ALTER COLUMN user_id SET NOT NULL
                        """
                    )
                    await conn.execute(
                        """
                        ALTER TABLE user_sessions
                        DROP COLUMN IF EXISTS username
                        """
                    )
                    await conn.execute(
                        """
                        ALTER TABLE user_activity_logs
                        ADD COLUMN IF NOT EXISTS user_id TEXT
                        """
                    )
                    await conn.execute(
                        """
                        DO $$
                        BEGIN
                          IF EXISTS (
                            SELECT 1
                            FROM information_schema.columns
                            WHERE table_name = 'user_activity_logs'
                              AND column_name = 'username'
                          ) THEN
                            UPDATE user_activity_logs
                            SET user_id = username
                            WHERE user_id IS NULL OR user_id = '';
                          END IF;
                        END $$;
                        """
                    )
                    await conn.execute(
                        """
                        ALTER TABLE user_activity_logs
                        ALTER COLUMN user_id SET NOT NULL
                        """
                    )
                    await conn.execute(
                        """
                        ALTER TABLE user_activity_logs
                        DROP COLUMN IF EXISTS username
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

    async def create_session(self, user_id: str) -> str:
        pool, redis = self._require_ready()
        now = _utcnow()
        expires_at = now + timedelta(seconds=self._timeout_seconds)
        session_id = str(uuid.uuid4())

        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO user_sessions (
                  session_id, user_id, created_at, last_activity_at, expires_at
                )
                VALUES ($1, $2, $3, $4, $5)
                """,
                session_id,
                user_id,
                now,
                now,
                expires_at,
            )

        payload = json.dumps({"user_id": user_id})
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
            cached_user_id = str(cache.get("user_id") or cache.get("username") or "").strip()
        except (TypeError, ValueError, json.JSONDecodeError):
            await redis.delete(key)
            return None
        if not cached_user_id:
            await redis.delete(key)
            return None

        now = _utcnow()
        expires_at = now + timedelta(seconds=self._timeout_seconds)
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT user_id, revoked_at
                FROM user_sessions
                WHERE session_id = $1
                """,
                session_id,
            )
            if row is None:
                await redis.delete(key)
                return None
            row_user_id = str(row["user_id"] or "").strip()
            if row["revoked_at"] is not None or row_user_id != cached_user_id:
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
        return cached_user_id

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
        user_id: str,
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
                  user_id,
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
                user_id,
                session_id,
                method,
                path,
                status_code,
                duration_ms,
                client_ip,
                user_agent,
            )

    async def upsert_user(
        self,
        *,
        user_id: str,
        provider: str,
        provider_user_id: str,
        role: str,
        nickname: str,
    ) -> None:
        pool, _ = self._require_ready()
        now = _utcnow()
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO users (
                  user_id,
                  provider,
                  provider_user_id,
                  role,
                  nickname,
                  created_at,
                  updated_at,
                  last_login_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $6, $6)
                ON CONFLICT (user_id)
                DO UPDATE SET
                  provider = EXCLUDED.provider,
                  provider_user_id = EXCLUDED.provider_user_id,
                  role = users.role,
                  nickname = EXCLUDED.nickname,
                  updated_at = EXCLUDED.updated_at,
                  last_login_at = EXCLUDED.last_login_at
                """,
                user_id,
                provider,
                provider_user_id,
                role,
                nickname,
                now,
            )

    async def get_user_nickname(self, user_id: str) -> str | None:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            value = await conn.fetchval(
                """
                SELECT nickname
                FROM users
                WHERE user_id = $1
                """,
                user_id,
            )
        if value is None:
            return None
        nickname = str(value).strip()
        return nickname or None

    async def get_user_role(self, user_id: str) -> str | None:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            value = await conn.fetchval(
                """
                SELECT role
                FROM users
                WHERE user_id = $1
                """,
                user_id,
            )
        if value is None:
            return None
        role = str(value).strip().lower()
        return role or None

    async def list_users(self) -> list[dict]:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT
                  user_id,
                  provider,
                  provider_user_id,
                  role,
                  nickname,
                  created_at,
                  updated_at,
                  last_login_at
                FROM users
                ORDER BY created_at DESC
                """
            )
        return [dict(row) for row in rows]

    async def fetch_user_activity_logs(
        self,
        *,
        log_type: str | None = None,
        limit: int = 50,
    ) -> list[dict]:
        pool, _ = self._require_ready()
        where_clauses: list[str] = []
        if log_type == 'system':
            where_clauses.append("path NOT LIKE '/api/%'")
        elif log_type == 'api':
            where_clauses.append("path LIKE '/api/%'")
        elif log_type == 'error':
            where_clauses.append('status_code >= 500')
        where_sql = ''
        if where_clauses:
            where_sql = 'WHERE ' + ' AND '.join(where_clauses)
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                f"""
                SELECT
                  occurred_at,
                  user_id,
                  session_id,
                  method,
                  path,
                  status_code,
                  duration_ms,
                  client_ip,
                  user_agent
                FROM user_activity_logs
                {where_sql}
                ORDER BY occurred_at DESC
                LIMIT $1
                """,
                limit,
            )
        return [dict(row) for row in rows]

    async def count_users(self) -> int:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            value = await conn.fetchval('SELECT COUNT(*) FROM users')
        return int(value or 0)

    async def count_unique_visitors_since(self, since: datetime) -> int:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            value = await conn.fetchval(
                """
                SELECT COUNT(DISTINCT user_id)
                FROM user_activity_logs
                WHERE occurred_at >= $1
                """,
                since,
            )
        return int(value or 0)

    async def count_api_calls_since(self, since: datetime) -> int:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            value = await conn.fetchval(
                """
                SELECT COUNT(*)
                FROM user_activity_logs
                WHERE occurred_at >= $1
                """,
                since,
            )
        return int(value or 0)

    async def aggregate_api_calls_by_hour(
        self,
        *,
        since: datetime,
    ) -> list[dict]:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT
                  date_trunc('hour', occurred_at) AS bucket,
                  COUNT(*) AS count
                FROM user_activity_logs
                WHERE occurred_at >= $1
                GROUP BY bucket
                ORDER BY bucket ASC
                """,
                since,
            )
        return [
            {
                'bucket': row['bucket'],
                'count': int(row['count'] or 0),
            }
            for row in rows
        ]

    async def record_llm_chat(
        self,
        *,
        user_id: str,
        model: str,
        prompt: str,
        response: str,
    ) -> None:
        pool, _ = self._require_ready()
        occurred_at = _utcnow()
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO llm_chat_logs (
                  occurred_at,
                  user_id,
                  model,
                  prompt,
                  response
                )
                VALUES ($1, $2, $3, $4, $5)
                """,
                occurred_at,
                user_id,
                model,
                prompt,
                response,
            )

    async def diary_entry_exists(self, person_id: str, sha256: str) -> bool:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            value = await conn.fetchval(
                """
                SELECT 1
                FROM diary_entries
                WHERE person_id = $1
                  AND sha256 = $2
                LIMIT 1
                """,
                person_id,
                sha256,
            )
        return value is not None

    async def insert_diary_entry(
        self,
        *,
        entry_id: uuid.UUID,
        person_id: str,
        storage_path: str,
        created_at: datetime,
        sha256: str,
        event_date: date | None,
        emotion_label: str | None,
        event_text: str | None,
        feeling_text: str | None,
        reason_text: str | None,
        next_action_text: str | None,
    ) -> dict:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO diary_entries (
                  id,
                  person_id,
                  storage_path,
                  created_at,
                  sha256,
                  event_date,
                  emotion_label,
                  event_text,
                  feeling_text,
                  reason_text,
                  next_action_text
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING *
                """,
                entry_id,
                person_id,
                storage_path,
                created_at,
                sha256,
                event_date,
                emotion_label,
                event_text,
                feeling_text,
                reason_text,
                next_action_text,
            )
        return dict(row) if row is not None else {}

    async def voice_archive_exists_sha256(self, sha256: str) -> bool:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            value = await conn.fetchval(
                """
                SELECT 1
                FROM voice_archives
                WHERE sha256 = $1
                LIMIT 1
                """,
                sha256,
            )
        return value is not None

    async def insert_voice_archive(
        self,
        *,
        entry_id: uuid.UUID,
        person_id: str,
        file_name: str,
        file_ext: str,
        storage_key: str,
        created_at: datetime,
        sha256: str,
        captured_at: datetime | None,
        tags: str,
        emotion: str | None,
        reference_text: str | None,
        stt_text: str | None,
    ) -> dict:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO voice_archives (
                  id,
                  person_id,
                  file_name,
                  file_ext,
                  storage_key,
                  created_at,
                  sha256,
                  captured_at,
                  tags,
                  emotion,
                  reference_text,
                  stt_text
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                RETURNING *
                """,
                entry_id,
                person_id,
                file_name,
                file_ext,
                storage_key,
                created_at,
                sha256,
                captured_at,
                tags,
                emotion,
                reference_text,
                stt_text,
            )
        return dict(row) if row is not None else {}

    async def list_voice_archive_completions(
        self,
        *,
        person_id: str,
        tags: str,
    ) -> list[dict]:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT
                  reference_text,
                  MAX(created_at) AS latest_created_at
                FROM voice_archives
                WHERE person_id = $1
                  AND tags = $2
                  AND reference_text IS NOT NULL
                  AND btrim(reference_text) <> ''
                GROUP BY reference_text
                ORDER BY latest_created_at DESC
                """,
                person_id,
                tags,
            )
        return [dict(row) for row in rows]

    async def delete_voice_archive(
        self,
        *,
        entry_id: uuid.UUID,
        person_id: str,
    ) -> dict:
        pool, _ = self._require_ready()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                DELETE FROM voice_archives
                WHERE id = $1
                  AND person_id = $2
                RETURNING *
                """,
                entry_id,
                person_id,
            )
        return dict(row) if row is not None else {}
