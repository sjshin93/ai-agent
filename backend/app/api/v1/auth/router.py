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
_TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"


def _role_for_user_id(user_id: str) -> str:
    if user_id in settings.admin_user_ids:
        return "admin"
    return "user"


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


async def _verify_turnstile(request: Request, token: str | None) -> bool:
    if not settings.turnstile_enabled:
        return True
    secret = settings.turnstile_secret_key.strip()
    if not secret:
        logger.warning("Turnstile is enabled but TURNSTILE_SECRET_KEY is not configured.")
        return False
    response_token = (token or "").strip()
    if not response_token:
        return False

    payload: dict[str, str] = {
        "secret": secret,
        "response": response_token,
    }
    client_ip = request.client.host if request.client and request.client.host else ""
    if client_ip:
        payload["remoteip"] = client_ip

    timeout = max(1.0, settings.http_timeout)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            verify_res = await client.post(_TURNSTILE_VERIFY_URL, data=payload)
            verify_res.raise_for_status()
            verify_data = verify_res.json()
    except Exception as exc:
        logger.warning("Turnstile verification request failed: %s", exc)
        return False

    success = bool(verify_data.get("success"))
    if not success:
        logger.info(
            "Turnstile verification rejected. errors=%s hostname=%s",
            verify_data.get("error-codes"),
            verify_data.get("hostname"),
        )
    return success


@router.get("/me", response_model=MeResponse)
async def me(request: Request):
    session_id = request.cookies.get(settings.session_cookie_name)
    if not session_id:
        return MeResponse(authenticated=False)
    user_id = await session_manager.validate_and_touch(session_id)
    if not user_id:
        return MeResponse(authenticated=False)
    nickname = await session_manager.get_user_nickname(user_id)
    role = await session_manager.get_user_role(user_id)
    return MeResponse(
        authenticated=True,
        user_id=user_id,
        nickname=nickname,
        role=role or "user",
    )


@router.post("/logout", response_model=LogoutResponse)
async def logout(request: Request, response: Response):
    session_id = request.cookies.get(settings.session_cookie_name)
    if session_id:
        await session_manager.revoke_session(session_id)
    response.delete_cookie(settings.session_cookie_name, path="/")
    return LogoutResponse()


@router.get("/google/login")
async def google_login(request: Request, turnstile_token: str | None = None):
    if not settings.google_client_id or not settings.google_client_secret:
        return JSONResponse(
            status_code=503,
            content={"detail": "GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET is not configured"},
        )
    if not await _verify_turnstile(request, turnstile_token):
        return _redirect(settings.google_failure_redirect)
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
            logger.info("Google OAuth userinfo: %s", userinfo)
    except Exception as exc:
        logger.warning("Google OAuth callback failed: %s", exc)
        return failure_redirect

    sub = str(userinfo.get("sub") or "").strip()
    name = str(userinfo.get("name") or "").strip()
    if not sub:
        return failure_redirect
    user_id = f"google_{sub}"
    nickname = name or user_id
    await session_manager.upsert_user(
        user_id=user_id,
        provider="google",
        provider_user_id=sub,
        role=_role_for_user_id(user_id),
        nickname=nickname,
    )

    session_id = await session_manager.create_session(user_id)
    success_redirect = _redirect(settings.google_success_redirect)
    _set_session_cookie(success_redirect, session_id)
    success_redirect.delete_cookie(_GOOGLE_STATE_COOKIE, path="/")
    return success_redirect


@router.get("/kakao/login")
async def kakao_login(request: Request, turnstile_token: str | None = None):
    if not settings.kakao_rest_api_key:
        return JSONResponse(
            status_code=503,
            content={"detail": "KAKAO_REST_API_KEY is not configured"},
        )
    if not await _verify_turnstile(request, turnstile_token):
        return _redirect(settings.kakao_failure_redirect)
    return _oauth_state_response(
        state_cookie_name=_KAKAO_STATE_COOKIE,
        authorize_url=_KAKAO_AUTH_URL,
        params={
            "client_id": settings.kakao_rest_api_key,
            "redirect_uri": settings.kakao_redirect_uri,
            "response_type": "code",
            "scope": "profile_nickname",
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
            logger.info("Kakao OAuth userinfo: %s", userinfo)
    except Exception as exc:
        logger.warning("Kakao OAuth callback failed: %s", exc)
        return failure_redirect

    properties = userinfo.get("properties") or {}
    nickname = str(properties.get("nickname") or "").strip()
    kakao_id = str(userinfo.get("id") or "").strip()
    if not kakao_id:
        return failure_redirect
    user_id = f"kakao_{kakao_id}"
    saved_nickname = nickname or user_id
    await session_manager.upsert_user(
        user_id=user_id,
        provider="kakao",
        provider_user_id=kakao_id,
        role=_role_for_user_id(user_id),
        nickname=saved_nickname,
    )

    session_id = await session_manager.create_session(user_id)
    success_redirect = _redirect(settings.kakao_success_redirect)
    _set_session_cookie(success_redirect, session_id)
    success_redirect.delete_cookie(_KAKAO_STATE_COOKIE, path="/")
    return success_redirect
