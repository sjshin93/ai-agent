import logging
from datetime import datetime
from time import perf_counter

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile

from app.core.config import settings
from app.core.session_manager import SessionManager
from app.dependencies import (
    get_voice_archive_service,
    get_diary_service,
    get_session_manager,
    get_voice_prompt_service,
)
from app.domains.diary.schemas import DiaryArchiveRequest, DiaryArchiveResponse
from app.domains.diary.service import DiaryDuplicateError, DiaryService
from app.domains.voice_archive.schemas import (
    VoiceArchiveBulkDeleteResponse,
    VoiceArchiveDeleteResponse,
    VoiceArchiveResponse,
)
from app.domains.voice_archive.service import (
    VoiceArchiveDuplicateError,
    VoiceArchiveNotFoundError,
    VoiceArchiveService,
)
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
    user_id, _ = await _require_authenticated_session(request, sessions)
    try:
        items = service.load(category)
    except VoicePromptLoadError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    archived_reference_texts = await sessions.list_archived_voice_reference_texts(
        person_id=user_id,
        tags=category,
    )
    enriched_items = [
        item.model_copy(
            update={"is_archived": item.text.strip() in archived_reference_texts}
        )
        for item in items
    ]
    return VoicePromptListResponse(
        category=category,
        count=len(enriched_items),
        items=enriched_items,
    )


@router.post("/voice", response_model=VoiceArchiveResponse)
async def archive_voice(
    request: Request,
    audio: UploadFile = File(...),
    tags: str = Form(""),
    emotion: str | None = Form(None),
    reference_text: str | None = Form(None),
    stt_text: str | None = Form(None),
    captured_at: str | None = Form(None),
    file_ext: str | None = Form(None),
    service: VoiceArchiveService = Depends(get_voice_archive_service),
    sessions: SessionManager = Depends(get_session_manager),
) -> VoiceArchiveResponse:
    user_id, _ = await _require_authenticated_session(request, sessions)
    body = await audio.read()
    if not body:
        logger.warning(
            "Voice archive rejected: empty audio payload user_id=%s filename=%s content_type=%s content_length=%s tags=%s",
            user_id,
            audio.filename,
            audio.content_type,
            request.headers.get("content-length"),
            tags,
        )
        raise HTTPException(status_code=400, detail="audio file is empty")

    parsed_captured_at: datetime | None = None
    if captured_at:
        value = captured_at.strip()
        if value:
            try:
                parsed_captured_at = datetime.fromisoformat(
                    value.replace("Z", "+00:00")
                )
            except ValueError as exc:
                logger.warning(
                    "Voice archive rejected: invalid captured_at user_id=%s captured_at=%s",
                    user_id,
                    captured_at,
                )
                raise HTTPException(
                    status_code=400,
                    detail="captured_at must be ISO-8601 datetime",
                ) from exc
    effective_ext = (file_ext or "").strip() or _infer_ext(audio.filename)
    try:
        response = await service.archive_voice(
            person_id=user_id,
            audio_bytes=body,
            file_ext=effective_ext,
            tags=tags,
            emotion=emotion,
            reference_text=reference_text,
            stt_text=stt_text,
            captured_at=parsed_captured_at,
        )
        logger.info(
            "Voice archive stored user_id=%s bytes=%s ext=%s tags=%s storage_key=%s",
            user_id,
            len(body),
            effective_ext,
            tags,
            response.storage_key,
        )
        return response
    except VoiceArchiveDuplicateError as exc:
        logger.info(
            "Voice archive duplicate user_id=%s sha256_conflict tags=%s",
            user_id,
            tags,
        )
        raise HTTPException(status_code=409, detail=str(exc)) from exc


def _infer_ext(filename: str | None) -> str:
    if not filename or "." not in filename:
        return "wav"
    return filename.rsplit(".", 1)[1]


@router.delete("/voice", response_model=VoiceArchiveDeleteResponse)
async def delete_voice(
    request: Request,
    storage_key: str,
    service: VoiceArchiveService = Depends(get_voice_archive_service),
    sessions: SessionManager = Depends(get_session_manager),
) -> VoiceArchiveDeleteResponse:
    user_id, _ = await _require_authenticated_session(request, sessions)
    cleaned_storage_key = storage_key.strip()
    if not cleaned_storage_key:
        raise HTTPException(status_code=400, detail="storage_key is required")
    try:
        deleted = await service.delete_voice_archive(
            person_id=user_id,
            storage_key=cleaned_storage_key,
        )
        return VoiceArchiveDeleteResponse(
            deleted=deleted,
            storage_key=cleaned_storage_key,
        )
    except VoiceArchiveNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete(
    "/voice/category/{category}",
    response_model=VoiceArchiveBulkDeleteResponse,
)
async def delete_voice_by_category(
    category: VoicePromptCategory,
    request: Request,
    service: VoiceArchiveService = Depends(get_voice_archive_service),
    sessions: SessionManager = Depends(get_session_manager),
) -> VoiceArchiveBulkDeleteResponse:
    user_id, _ = await _require_authenticated_session(request, sessions)
    deleted_count = await service.delete_voice_archives_by_tags(
        person_id=user_id,
        tags=category,
    )
    return VoiceArchiveBulkDeleteResponse(
        deleted_count=deleted_count,
        tags=category,
    )
