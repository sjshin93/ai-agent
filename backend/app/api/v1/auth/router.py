import logging
import secrets
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Request, Response
from fastapi.responses import JSONResponse, RedirectResponse

from app.core.config import settings
from app.core.session_state import session_manager
from app.domains.auth.schemas import LogoutResponse, MeResponse

router = APIRouter()
logger = logging.getLogger("uvicorn.error")

_GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
_GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
_GOOGLE_USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"
_GOOGLE_STATE_COOKIE = "oauth_state_google"

_KAKAO_AUTH_URL = "https://kauth.kakao.com/oauth/authorize"
_KAKAO_TOKEN_URL = "https://kauth.kakao.com/oauth/token"
_KAKAO_USERINFO_URL = "https://kapi.kakao.com/v2/user/me"
_KAKAO_STATE_COOKIE = "oauth_state_kakao"


def _set_session_cookie(response: Response, session_id: str) -> None:
    response.set_cookie(
        key=settings.session_cookie_name,
        value=session_id,
        max_age=settings.auto_logout_seconds,
        httponly=True,
        secure=settings.session_cookie_secure,
        samesite="lax",
        path="/",
    )


def _redirect(url: str) -> RedirectResponse:
    return RedirectResponse(url=url, status_code=302)


def _oauth_state_response(
    *,
    state_cookie_name: str,
    authorize_url: str,
    params: dict[str, str],
) -> RedirectResponse:
    state = secrets.token_urlsafe(24)
    params["state"] = state
    response = _redirect(f"{authorize_url}?{urlencode(params)}")
    response.set_cookie(
        key=state_cookie_name,
        value=state,
        max_age=600,
        httponly=True,
        secure=settings.session_cookie_secure,
        samesite="lax",
        path="/",
    )
    return response


@router.get("/me", response_model=MeResponse)
async def me(request: Request):
    session_id = request.cookies.get(settings.session_cookie_name)
    if not session_id:
        return MeResponse(authenticated=False)
    username = await session_manager.validate_and_touch(session_id)
    if not username:
        return MeResponse(authenticated=False)
    return MeResponse(authenticated=True, username=username)


@router.post("/logout", response_model=LogoutResponse)
async def logout(request: Request, response: Response):
    session_id = request.cookies.get(settings.session_cookie_name)
    if session_id:
        await session_manager.revoke_session(session_id)
    response.delete_cookie(settings.session_cookie_name, path="/")
    return LogoutResponse()


@router.get("/google/login")
async def google_login():
    if not settings.google_client_id or not settings.google_client_secret:
        return JSONResponse(
            status_code=503,
            content={"detail": "GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET is not configured"},
        )
    return _oauth_state_response(
        state_cookie_name=_GOOGLE_STATE_COOKIE,
        authorize_url=_GOOGLE_AUTH_URL,
        params={
            "client_id": settings.google_client_id,
            "redirect_uri": settings.google_redirect_uri,
            "response_type": "code",
            "scope": "openid email profile",
            "access_type": "online",
            "prompt": "select_account",
        },
    )


@router.get("/google/callback")
async def google_callback(
    request: Request,
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
):
    failure_redirect = _redirect(settings.google_failure_redirect)
    if error or not code or not state:
        return failure_redirect

    state_cookie = request.cookies.get(_GOOGLE_STATE_COOKIE)
    if not state_cookie or state_cookie != state:
        return failure_redirect

    timeout = max(1.0, settings.http_timeout)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            token_res = await client.post(
                _GOOGLE_TOKEN_URL,
                data={
                    "code": code,
                    "client_id": settings.google_client_id,
                    "client_secret": settings.google_client_secret,
                    "redirect_uri": settings.google_redirect_uri,
                    "grant_type": "authorization_code",
                },
            )
            token_res.raise_for_status()
            token_data = token_res.json()
            access_token = str(token_data.get("access_token") or "").strip()
            if not access_token:
                return failure_redirect

            userinfo_res = await client.get(
                _GOOGLE_USERINFO_URL,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            userinfo_res.raise_for_status()
            userinfo = userinfo_res.json()
    except Exception as exc:
        logger.warning("Google OAuth callback failed: %s", exc)
        return failure_redirect

    email = str(userinfo.get("email") or "").strip()
    sub = str(userinfo.get("sub") or "").strip()
    username = email or sub
    if not username:
        return failure_redirect

    session_id = await session_manager.create_session(username)
    success_redirect = _redirect(settings.google_success_redirect)
    _set_session_cookie(success_redirect, session_id)
    success_redirect.delete_cookie(_GOOGLE_STATE_COOKIE, path="/")
    return success_redirect


@router.get("/kakao/login")
async def kakao_login():
    if not settings.kakao_rest_api_key:
        return JSONResponse(
            status_code=503,
            content={"detail": "KAKAO_REST_API_KEY is not configured"},
        )
    return _oauth_state_response(
        state_cookie_name=_KAKAO_STATE_COOKIE,
        authorize_url=_KAKAO_AUTH_URL,
        params={
            "client_id": settings.kakao_rest_api_key,
            "redirect_uri": settings.kakao_redirect_uri,
            "response_type": "code",
            "scope": "account_email profile_nickname",
            "prompt": "login",
        },
    )


@router.get("/kakao/callback")
async def kakao_callback(
    request: Request,
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
):
    failure_redirect = _redirect(settings.kakao_failure_redirect)
    if error or not code or not state:
        return failure_redirect

    state_cookie = request.cookies.get(_KAKAO_STATE_COOKIE)
    if not state_cookie or state_cookie != state:
        return failure_redirect

    timeout = max(1.0, settings.http_timeout)
    token_payload = {
        "grant_type": "authorization_code",
        "client_id": settings.kakao_rest_api_key,
        "redirect_uri": settings.kakao_redirect_uri,
        "code": code,
    }
    if settings.kakao_client_secret:
        token_payload["client_secret"] = settings.kakao_client_secret

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            token_res = await client.post(_KAKAO_TOKEN_URL, data=token_payload)
            token_res.raise_for_status()
            token_data = token_res.json()
            access_token = str(token_data.get("access_token") or "").strip()
            if not access_token:
                return failure_redirect

            userinfo_res = await client.get(
                _KAKAO_USERINFO_URL,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            userinfo_res.raise_for_status()
            userinfo = userinfo_res.json()
    except Exception as exc:
        logger.warning("Kakao OAuth callback failed: %s", exc)
        return failure_redirect

    kakao_account = userinfo.get("kakao_account") or {}
    properties = userinfo.get("properties") or {}
    email = str(kakao_account.get("email") or "").strip()
    nickname = str(properties.get("nickname") or "").strip()
    kakao_id = str(userinfo.get("id") or "").strip()
    username = email or nickname or kakao_id
    if not username:
        return failure_redirect

    session_id = await session_manager.create_session(username)
    success_redirect = _redirect(settings.kakao_success_redirect)
    _set_session_cookie(success_redirect, session_id)
    success_redirect.delete_cookie(_KAKAO_STATE_COOKIE, path="/")
    return success_redirect
