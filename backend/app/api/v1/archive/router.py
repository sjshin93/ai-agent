import logging
from time import perf_counter

from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.config import settings
from app.core.session_manager import SessionManager
from app.dependencies import (
    get_diary_service,
    get_session_manager,
    get_voice_prompt_service,
)
from app.domains.diary.schemas import DiaryArchiveRequest, DiaryArchiveResponse
from app.domains.diary.service import DiaryDuplicateError, DiaryService
from app.domains.voice_prompts.schemas import (
    VoicePromptCategory,
    VoicePromptListResponse,
)
from app.domains.voice_prompts.service import VoicePromptLoadError, VoicePromptService

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


async def _require_authenticated_session(
    request: Request,
    sessions: SessionManager,
) -> tuple[str, str]:
    session_id = request.cookies.get(settings.session_cookie_name)
    if not session_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    user_id = await sessions.validate_and_touch(session_id)
    if not user_id:
        raise HTTPException(
            status_code=401, detail="Session expired. Please sign in again."
        )
    return str(user_id), session_id


@router.post("/diary", response_model=DiaryArchiveResponse)
async def archive_diary(
    payload: DiaryArchiveRequest,
    request: Request,
    diary_service: DiaryService = Depends(get_diary_service),
    sessions: SessionManager = Depends(get_session_manager),
) -> DiaryArchiveResponse:
    user_id, session_id = await _require_authenticated_session(request, sessions)
    if payload.person_id and payload.person_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="person_id must match authenticated user",
        )
    person_id = payload.person_id or user_id
    start = perf_counter()
    try:
        response = await diary_service.archive_diary(payload, person_id)
    except DiaryDuplicateError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    duration_ms = int((perf_counter() - start) * 1000)
    client_ip = request.client.host if request.client else "unknown"
    user_agent = request.headers.get("user-agent", "")
    try:
        await sessions.record_activity(
            user_id=user_id,
            session_id=session_id,
            method=request.method,
            path=str(request.url.path),
            status_code=200,
            duration_ms=duration_ms,
            client_ip=client_ip,
            user_agent=user_agent,
        )
    except Exception as exc:  # pragma: no cover - best-effort logging
        logger.warning("Failed to record diary activity: %s", exc)
    return response


@router.get("/voice-prompts/{category}", response_model=VoicePromptListResponse)
async def list_voice_prompts(
    category: VoicePromptCategory,
    request: Request,
    service: VoicePromptService = Depends(get_voice_prompt_service),
    sessions: SessionManager = Depends(get_session_manager),
) -> VoicePromptListResponse:
    await _require_authenticated_session(request, sessions)
    try:
        items = service.load(category)
    except VoicePromptLoadError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return VoicePromptListResponse(
        category=category,
        count=len(items),
        items=items,
    )
