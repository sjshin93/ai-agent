import logging
import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.core.config import settings
from app.core.session_manager import SessionManager

logger = logging.getLogger("uvicorn.error")

_PUBLIC_PATHS = {
    "/health",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/auth/me",
    "/auth/google/login",
    "/auth/google/callback",
    "/auth/kakao/login",
    "/auth/kakao/callback",
    "/config/auto-logout",
    "/config/version",
}


def _is_public_path(path: str) -> bool:
    normalized = path.rstrip("/") or "/"
    if normalized.startswith("/api/"):
        normalized = normalized[4:]
    elif normalized == "/api":
        normalized = "/"
    return normalized in _PUBLIC_PATHS


class SessionAuthMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, session_manager: SessionManager) -> None:
        super().__init__(app)
        self._session_manager = session_manager
        self._cookie_name = settings.session_cookie_name

    async def dispatch(self, request: Request, call_next):
        path = request.url.path.rstrip("/") or "/"
        if path.startswith("/api/"):
            path = path[4:]
        elif path == "/api":
            path = "/"
        if _is_public_path(path):
            return await call_next(request)

        session_id = request.cookies.get(self._cookie_name)
        if not session_id:
            return JSONResponse(
                status_code=401,
                content={"detail": "Authentication required"},
            )

        user_id = await self._session_manager.validate_and_touch(session_id)
        if not user_id:
            return JSONResponse(
                status_code=401,
                content={"detail": "Session expired. Please sign in again."},
            )

        request.state.user_id = user_id
        request.state.username = user_id
        request.state.session_id = session_id
        started = time.perf_counter()
        response = await call_next(request)
        duration_ms = int((time.perf_counter() - started) * 1000)
        client_ip = request.client.host if request.client else "unknown"
        user_agent = request.headers.get("user-agent", "")
        try:
            await self._session_manager.record_activity(
                user_id=user_id,
                session_id=session_id,
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                duration_ms=duration_ms,
                client_ip=client_ip,
                user_agent=user_agent,
            )
        except Exception as exc:  # pragma: no cover - non-critical logging path
            logger.warning("Failed to persist activity log: %s", exc)
        return response
