from __future__ import annotations

import asyncio
import logging
import random
from dataclasses import dataclass

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class HttpRetryConfig:
    retries: int = 1
    backoff_seconds: float = 0.3
    max_backoff_seconds: float = 2.0


class HttpClient:
    def __init__(
        self,
        *,
        timeout: float | None = None,
        retry: HttpRetryConfig | None = None,
    ) -> None:
        self._timeout = timeout if timeout is not None else settings.http_timeout
        self._retry = retry or HttpRetryConfig(retries=settings.http_retry)

    async def request(self, method: str, url: str, **kwargs) -> httpx.Response:
        attempts = (self._retry.retries + 1) if self._retry else 1
        last_exc: Exception | None = None
        for attempt in range(1, attempts + 1):
            try:
                verify = kwargs.pop("verify", None)
                client_kwargs = {"timeout": self._timeout}
                if verify is not None:
                    client_kwargs["verify"] = verify
                async with httpx.AsyncClient(**client_kwargs) as client:
                    response = await client.request(method, url, **kwargs)
                if self._should_retry_response(response, attempt, attempts):
                    await self._sleep_backoff(attempt)
                    continue
                return response
            except httpx.HTTPError as exc:
                last_exc = exc
                if attempt >= attempts:
                    break
                logger.warning("HTTP request failed (attempt %s/%s): %s", attempt, attempts, exc)
                await self._sleep_backoff(attempt)
        if last_exc:
            raise last_exc
        raise RuntimeError("HTTP request failed without response")

    @staticmethod
    def _should_retry_response(
        response: httpx.Response, attempt: int, attempts: int
    ) -> bool:
        if attempt >= attempts:
            return False
        return response.status_code in {408, 429} or response.status_code >= 500

    async def _sleep_backoff(self, attempt: int) -> None:
        if not self._retry:
            return
        base = min(self._retry.backoff_seconds * (2 ** (attempt - 1)), self._retry.max_backoff_seconds)
        jitter = random.uniform(0, base * 0.2)
        await asyncio.sleep(base + jitter)
