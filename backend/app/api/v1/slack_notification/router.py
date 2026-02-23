import logging

from fastapi import APIRouter, Depends, Request

from app.dependencies import get_slack_notification_service
from app.domains.slack_notification.schemas import (
    SlackNotificationRequest,
    SlackNotificationResponse,
)
from app.domains.slack_notification.service import SlackNotificationService

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.post("/slack", response_model=SlackNotificationResponse)
async def send_slack_notification(
    payload: SlackNotificationRequest,
    service: SlackNotificationService = Depends(get_slack_notification_service),
    request: Request = None,
):
    # TODO: replace with real result object from Slack.
    client_ip = request.client.host if request and request.client else "unknown"
    user = getattr(request.state, "username", "anonymous") if request else "anonymous"
    await service.send_slack_notification(message=payload.message)
    logger.info(
        "slack.notification.sent",
        extra={
            "event": "slack.notification.sent",
            "user": user,
            "ip": client_ip,
            "message_length": len(payload.message),
        },
    )
    return SlackNotificationResponse(ok=True)
