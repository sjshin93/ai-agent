from fastapi import APIRouter, Depends, HTTPException, Request

from app.core.config import settings
from app.core.session_manager import SessionManager
from app.dependencies import get_diary_service, get_session_manager
from app.domains.diary.schemas import DiaryArchiveRequest, DiaryArchiveResponse
from app.domains.diary.service import DiaryDuplicateError, DiaryService

router = APIRouter()


async def _require_authenticated_session(
    request: Request,
    sessions: SessionManager,
) -> str:
    session_id = request.cookies.get(settings.session_cookie_name)
    if not session_id:
        raise HTTPException(status_code=401, detail="Authentication required")
    user_id = await sessions.validate_and_touch(session_id)
    if not user_id:
        raise HTTPException(
            status_code=401, detail="Session expired. Please sign in again."
        )
    return str(user_id)


@router.post("/diary", response_model=DiaryArchiveResponse)
async def archive_diary(
    payload: DiaryArchiveRequest,
    request: Request,
    diary_service: DiaryService = Depends(get_diary_service),
    sessions: SessionManager = Depends(get_session_manager),
) -> DiaryArchiveResponse:
    user_id = await _require_authenticated_session(request, sessions)
    if payload.person_id and payload.person_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="person_id must match authenticated user",
        )
    person_id = payload.person_id or user_id
    try:
        return await diary_service.archive_diary(payload, person_id)
    except DiaryDuplicateError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
