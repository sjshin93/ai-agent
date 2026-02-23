import logging

from fastapi import APIRouter, Depends, HTTPException, Request

from app.dependencies import get_ssh_service
from app.domains.ssh.schemas import SshTopRequest, SshTopResponse
from app.domains.ssh.service import SshService

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.post("/top", response_model=SshTopResponse)
def fetch_top(
    payload: SshTopRequest,
    service: SshService = Depends(get_ssh_service),
    request: Request = None,
):
    client_ip = request.client.host if request and request.client else "unknown"
    user = getattr(request.state, "username", None) if request else None
    if not user:
        user = payload.username or "unknown"
    command = payload.command or "top"
    try:
        logger.info(
            "ssh.request",
            extra={
                "event": "ssh.request",
                "user": user,
                "ip": client_ip,
                "site_id": payload.site_id,
                "command": command,
            },
        )
        output = service.fetch_top(payload.site_id, payload.command)
        logger.info(
            "ssh.response",
            extra={
                "event": "ssh.response",
                "user": user,
                "ip": client_ip,
                "site_id": payload.site_id,
                "command": command,
                "output_length": len(output),
            },
        )
        return SshTopResponse(output=output)
    except (ValueError, RuntimeError) as exc:
        logger.warning(
            "ssh.failed",
            extra={
                "event": "ssh.failed",
                "user": user,
                "ip": client_ip,
                "site_id": payload.site_id,
                "command": command,
                "error": str(exc),
            },
        )
        raise HTTPException(status_code=400, detail=str(exc)) from exc
