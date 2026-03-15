import logging
from json import JSONDecodeError

from fastapi import APIRouter, Request

from app.core.config import settings
from app.domains.config.schemas import (
    AutoLogoutConfigResponse,
    SessionTouchResponse,
    TurnstileConfigResponse,
    VersionConfigResponse,
)

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.get("/auto-logout", response_model=AutoLogoutConfigResponse)
def get_auto_logout_config(request: Request):
    client_ip = request.client.host if request.client else "unknown"
    user = getattr(request.state, "username", "anonymous")
    logger.info(
        "config.auto_logout.read",
        extra={
            "event": "config.auto_logout.read",
            "user": user,
            "ip": client_ip,
            "auto_logout_seconds": settings.auto_logout_seconds,
        },
    )
    return AutoLogoutConfigResponse(
        auto_logout_seconds=settings.auto_logout_seconds,
    )


@router.get("/version", response_model=VersionConfigResponse)
def get_version_config(request: Request):
    client_ip = request.client.host if request.client else "unknown"
    user = getattr(request.state, "username", "anonymous")
    logger.info(
        "config.version.read",
        extra={
            "event": "config.version.read",
            "user": user,
            "ip": client_ip,
            "version": settings.version,
        },
    )
    return VersionConfigResponse(version=settings.version)


@router.post("/session-touch", response_model=SessionTouchResponse)
def touch_session(request: Request):
    # Session TTL refresh is handled by SessionAuthMiddleware.
    client_ip = request.client.host if request.client else "unknown"
    user = getattr(request.state, "username", "anonymous")
    logger.info(
        "session.touch",
        extra={
            "event": "session.touch",
            "user": user,
            "ip": client_ip,
        },
    )
    return SessionTouchResponse(ok=True)


@router.get("/turnstile", response_model=TurnstileConfigResponse)
def get_turnstile_config(request: Request):
    client_ip = request.client.host if request.client else "unknown"
    user = getattr(request.state, "username", "anonymous")
    enabled = (
        settings.turnstile_enabled
        and bool(settings.turnstile_site_key.strip())
        and bool(settings.turnstile_secret_key.strip())
    )
    logger.info(
        "config.turnstile.read",
        extra={
            "event": "config.turnstile.read",
            "user": user,
            "ip": client_ip,
            "enabled": enabled,
        },
    )
    return TurnstileConfigResponse(
        enabled=enabled,
        site_key=settings.turnstile_site_key.strip() if enabled else None,
    )


@router.post("/turnstile-client-log")
async def turnstile_client_log(request: Request):
    client_ip = request.client.host if request.client else "unknown"
    body = await request.body()
    text = body.decode("utf-8", errors="replace").strip() if body else ""
    payload: dict[str, object]
    try:
        payload = await request.json()
        if not isinstance(payload, dict):
            payload = {"raw": payload}
    except (JSONDecodeError, UnicodeDecodeError):
        payload = {"raw": text}
    logger.info(
        "turnstile.client.log",
        extra={
            "event": "turnstile.client.log",
            "ip": client_ip,
            "payload": payload,
        },
    )
    return {"ok": True}
