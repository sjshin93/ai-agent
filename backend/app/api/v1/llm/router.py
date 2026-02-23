import logging

from fastapi import APIRouter, Depends, Request

from app.dependencies import get_llm_service
from app.domains.llm.schemas import LlmQueryRequest, LlmQueryResponse
from app.domains.llm.service import LlmService

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.post("/query", response_model=LlmQueryResponse)
async def query_llm(
    payload: LlmQueryRequest,
    service: LlmService = Depends(get_llm_service),
    request: Request = None,
):
    client_ip = request.client.host if request and request.client else "unknown"
    user = getattr(request.state, "username", "anonymous") if request else "anonymous"
    output = await service.query(prompt=payload.prompt, model=payload.model)
    logger.info(
        "llm.query.done",
        extra={
            "event": "llm.query.done",
            "user": user,
            "ip": client_ip,
            "model": payload.model,
            "prompt_length": len(payload.prompt),
            "output_length": len(output),
        },
    )
    return LlmQueryResponse(output=output)
