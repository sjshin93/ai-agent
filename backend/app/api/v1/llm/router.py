import logging
import time

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
    session_cookie = (
        request.cookies.get(settings.session_cookie_name) if request else None
    )
    start = time.perf_counter()
    output = await service.query(prompt=payload.prompt, model=payload.model)
    duration_ms = int((time.perf_counter() - start) * 1000)
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
    if session_cookie is not None and user_id != "anonymous":
        try:
            await sessions.record_activity(
                user_id=user_id,
                session_id=session_cookie,
                method=request.method if request else "POST",
                path=request.url.path if request else "/llm/query",
                status_code=200,
                duration_ms=duration_ms,
                client_ip=client_ip,
                user_agent=request.headers.get("user-agent", "")
                if request
                else "",
            )
        except Exception as exc:
            logger.warning("Failed to persist activity log for LLM query: %s", exc)
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
