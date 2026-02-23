import logging

from fastapi import APIRouter, Depends, Request

from app.dependencies import get_danji_service
from app.domains.danji.schemas import DanjiEvent, DanjiEventAck, DanjiRequest, DanjiResponse
from app.domains.danji.service import DanjiService

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.post("/request", response_model=DanjiResponse)
def send_danji_request(
    payload: DanjiRequest,
    service: DanjiService = Depends(get_danji_service),
    request: Request = None,
):
    client_ip = request.client.host if request and request.client else "unknown"
    user = getattr(request.state, "username", "anonymous") if request else "anonymous"
    data = service.send_request(action=payload.action, payload=payload.payload)
    logger.info(
        "danji.request.sent",
        extra={
            "event": "danji.request.sent",
            "user": user,
            "ip": client_ip,
            "action": payload.action,
        },
    )
    return DanjiResponse(status="ok", data=data)


@router.post("/events", response_model=DanjiEventAck)
def receive_danji_event(
    payload: DanjiEvent,
    service: DanjiService = Depends(get_danji_service),
    request: Request = None,
):
    client_ip = request.client.host if request and request.client else "unknown"
    user = getattr(request.state, "username", "anonymous") if request else "anonymous"
    service.handle_event(event_type=payload.event_type, payload=payload.payload)
    logger.info(
        "danji.event.received",
        extra={
            "event": "danji.event.received",
            "user": user,
            "ip": client_ip,
            "event_type": payload.event_type,
        },
    )
    return DanjiEventAck(accepted=True)
