import logging

from fastapi import APIRouter, Depends, Request

from app.dependencies import get_llm_service, get_session_manager
from app.domains.llm.schemas import LlmQueryRequest, LlmQueryResponse
from app.domains.llm.service import LlmService
from app.core.config import settings
from app.core.session_manager import SessionManager

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.post("/query", response_model=LlmQueryResponse)
async def query_llm(
    payload: LlmQueryRequest,
    service: LlmService = Depends(get_llm_service),
    sessions: SessionManager = Depends(get_session_manager),
    request: Request = None,
):
    client_ip = request.client.host if request and request.client else "unknown"
    user_id = await _resolve_user_id(request, sessions) if request else "anonymous"
    output = await service.query(prompt=payload.prompt, model=payload.model)
    model_name = (payload.model or "").strip() or "gemini-flash-latest"
    try:
        await sessions.record_llm_chat(
            user_id=user_id,
            model=model_name,
            prompt=payload.prompt,
            response=output,
        )
    except Exception as exc:  # pragma: no cover - non-critical persistence path
        logger.warning("Failed to persist llm chat log: %s", exc)
    logger.info(
        "llm.query.done",
        extra={
            "event": "llm.query.done",
            "user": user_id,
            "ip": client_ip,
            "model": model_name,
            "prompt_length": len(payload.prompt),
            "output_length": len(output),
        },
    )
    return LlmQueryResponse(output=output)


async def _resolve_user_id(request: Request, sessions: SessionManager) -> str:
    state_user_id = getattr(request.state, "user_id", None)
    if isinstance(state_user_id, str) and state_user_id.strip():
        return state_user_id.strip()
    session_id = request.cookies.get(settings.session_cookie_name)
    if session_id:
        user_id = await sessions.validate_and_touch(session_id)
        if user_id:
            return user_id
    return "anonymous"
