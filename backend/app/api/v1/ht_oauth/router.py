import logging

from fastapi import APIRouter, Depends, Request, Response

from app.core.config import settings
from app.dependencies import get_ht_oauth_service, get_session_manager
from app.core.session_manager import SessionManager
from app.domains.ht_oauth.schemas import (
    HtOauthLoginRequest,
    HtOauthLoginResponse,
    HtOauthLogoutRequest,
    HtOauthLogoutResponse,
    HtOauthRebootRequest,
    HtOauthRebootResponse,
)
from app.domains.ht_oauth.service import HtOauthService

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.post("/login", response_model=HtOauthLoginResponse)
async def login(
    payload: HtOauthLoginRequest,
    request: Request,
    response: Response,
    service: HtOauthService = Depends(get_ht_oauth_service),
    sessions: SessionManager = Depends(get_session_manager),
):
    ok, detail, access_token = await service.login(
        payload.username, payload.password
    )
    client_ip = request.client.host if request and request.client else "unknown"
    logger.info(
        "ht_oauth.login",
        extra={
            "event": "ht_oauth.login",
            "user": payload.username,
            "ip": client_ip,
            "ok": ok,
        },
    )
    if ok and access_token:
        session_id = await sessions.create_session(payload.username)
        response.set_cookie(
            key=settings.session_cookie_name,
            value=session_id,
            max_age=settings.auto_logout_seconds,
            httponly=True,
            secure=settings.session_cookie_secure,
            samesite="lax",
            path="/",
        )
    elif ok and not access_token:
        ok = False
        detail = detail or "HT OAuth access token missing"
    return HtOauthLoginResponse(ok=ok, detail=detail, access_token=access_token)


@router.post("/logout", response_model=HtOauthLogoutResponse)
async def logout(
    payload: HtOauthLogoutRequest,
    request: Request,
    response: Response,
    sessions: SessionManager = Depends(get_session_manager),
):
    client_ip = request.client.host if request and request.client else "unknown"
    logger.info(
        "ht_oauth.logout",
        extra={
            "event": "ht_oauth.logout",
            "user": payload.username,
            "ip": client_ip,
        },
    )
    session_id = request.cookies.get(settings.session_cookie_name)
    if session_id:
        await sessions.revoke_session(session_id)
    response.delete_cookie(settings.session_cookie_name, path="/")
    return HtOauthLogoutResponse(ok=True)


@router.post("/reboot", response_model=HtOauthRebootResponse)
async def reboot(
    payload: HtOauthRebootRequest,
    request: Request,
    service: HtOauthService = Depends(get_ht_oauth_service),
):
    auth_header = request.headers.get("authorization") or ""
    token = ""
    if auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ", 1)[1].strip()

    ok, detail, data, error_type = await service.reboot_wallpad(
        access_token=token,
        site_id=payload.site_id,
        dong=payload.dong,
        ho=payload.ho,
    )

    client_ip = request.client.host if request and request.client else "unknown"
    if ok:
        log_event = "ht_oauth.reboot.success"
        log_fn = logger.info
    elif error_type == "REQUEST_FAILED":
        log_event = "ht_oauth.reboot.request_failed"
        log_fn = logger.error
    elif error_type == "WALLPAD_RESPONSE_ERROR":
        log_event = "ht_oauth.reboot.wallpad_response_error"
        log_fn = logger.warning
    else:
        log_event = "ht_oauth.reboot.failed"
        log_fn = logger.warning
    log_fn(
        log_event,
        extra={
            "event": log_event,
            "ip": client_ip,
            "ok": ok,
            "error_type": error_type,
            "detail": detail,
            "site_id": payload.site_id,
            "dong": payload.dong,
            "ho": payload.ho,
        },
    )
    return HtOauthRebootResponse(
        ok=ok,
        error_type=error_type,
        detail=detail,
        data=data,
    )
