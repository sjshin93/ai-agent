import logging

from fastapi import APIRouter, Depends, Request

from app.dependencies import get_dj_oauth_service
from app.domains.dj_oauth.schemas import (
    DjOauthLoginRequest,
    DjOauthLoginResponse,
    DjOauthHouseholdRequest,
    DjOauthHouseholdResponse,
    DjOauthLogoutRequest,
    DjOauthLogoutResponse,
)
from app.domains.dj_oauth.service import DjOauthService

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.post("/login", response_model=DjOauthLoginResponse)
async def login(
    payload: DjOauthLoginRequest,
    request: Request,
    service: DjOauthService = Depends(get_dj_oauth_service),
):
    ok, detail, access_token = await service.login(
        user_id=payload.user_id,
        password=payload.password,
    )
    client_ip = request.client.host if request and request.client else "unknown"
    logger.info(
        "dj_oauth.login",
        extra={
            "event": "dj_oauth.login",
            "user": payload.user_id,
            "ip": client_ip,
            "ok": ok,
        },
    )
    return DjOauthLoginResponse(ok=ok, detail=detail, access_token=access_token)


@router.post("/household", response_model=DjOauthHouseholdResponse)
async def create_household(
    payload: DjOauthHouseholdRequest,
    request: Request,
    service: DjOauthService = Depends(get_dj_oauth_service),
):
    auth_header = request.headers.get("authorization") or ""
    token = ""
    if auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ", 1)[1].strip()
    ok, detail, data = await service.create_household_access(
        access_token=token,
        site_id=payload.site_id,
        dong=payload.dong,
        ho=payload.ho,
        nickname=payload.nickname,
    )
    client_ip = request.client.host if request and request.client else "unknown"
    logger.info(
        "dj_oauth.household",
        extra={
            "event": "dj_oauth.household",
            "user": payload.nickname,
            "ip": client_ip,
            "ok": ok,
            "site_id": payload.site_id,
            "dong": payload.dong,
            "ho": payload.ho,
        },
    )
    return DjOauthHouseholdResponse(ok=ok, detail=detail, data=data)


@router.post("/logout", response_model=DjOauthLogoutResponse)
async def logout(payload: DjOauthLogoutRequest, request: Request):
    client_ip = request.client.host if request and request.client else "unknown"
    logger.info(
        "dj_oauth.logout",
        extra={
            "event": "dj_oauth.logout",
            "user": payload.user_id,
            "ip": client_ip,
        },
    )
    return DjOauthLogoutResponse(ok=True)
