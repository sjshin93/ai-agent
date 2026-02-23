import logging

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile

from app.dependencies import get_jira_service
from app.domains.jira.data import fetch_options
from app.domains.jira.schemas import (
    JiraFieldOptionsResponse,
    JiraIssueCreateRequest,
    JiraIssueCreateResponse,
)
from app.domains.jira.service import JiraService

router = APIRouter()
logger = logging.getLogger("uvicorn.error")


@router.post("/issues", response_model=JiraIssueCreateResponse)
async def create_issue(
    payload: JiraIssueCreateRequest,
    service: JiraService = Depends(get_jira_service),
    request: Request = None,
):
    client_ip = request.client.host if request and request.client else "unknown"
    user = getattr(request.state, "username", "anonymous") if request else "anonymous"
    title = payload.title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="title is required")
    customer_part = payload.customer_part.strip()
    req_type = payload.req_type.strip()
    if not customer_part:
        raise HTTPException(status_code=400, detail="customer_part is required")
    if not req_type:
        raise HTTPException(status_code=400, detail="req_type is required")
    try:
        result = await service.create_task(
            title=title,
            description=payload.description,
            customer_part=customer_part,
            req_type=req_type,
        )
    except RuntimeError as exc:
        logger.warning(
            "jira.issue.create.failed",
            extra={
                "event": "jira.issue.create.failed",
                "user": user,
                "ip": client_ip,
                "customer_part": customer_part,
                "req_type": req_type,
                "error": str(exc),
            },
        )
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    logger.info(
        "jira.issue.create.done",
        extra={
            "event": "jira.issue.create.done",
            "user": user,
            "ip": client_ip,
            "customer_part": customer_part,
            "req_type": req_type,
            "issue_key": result.get("key"),
        },
    )
    return JiraIssueCreateResponse(**result)


@router.post("/issues-with-attachments", response_model=JiraIssueCreateResponse)
async def create_issue_with_attachments(
    title: str = Form(...),
    description: str = Form(""),
    customer_part: str = Form(...),
    req_type: str = Form(...),
    files: list[UploadFile] = File(default=[]),
    service: JiraService = Depends(get_jira_service),
    request: Request = None,
):
    client_ip = request.client.host if request and request.client else "unknown"
    user = getattr(request.state, "username", "anonymous") if request else "anonymous"
    title = title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="title is required")
    customer_part = customer_part.strip()
    req_type = req_type.strip()
    if not customer_part:
        raise HTTPException(status_code=400, detail="customer_part is required")
    if not req_type:
        raise HTTPException(status_code=400, detail="req_type is required")
    try:
        result = await service.create_task_with_attachments(
            title=title,
            description=description,
            customer_part=customer_part,
            req_type=req_type,
            files=files,
        )
    except RuntimeError as exc:
        logger.warning(
            "jira.issue.create_with_attachments.failed",
            extra={
                "event": "jira.issue.create_with_attachments.failed",
                "user": user,
                "ip": client_ip,
                "customer_part": customer_part,
                "req_type": req_type,
                "file_count": len(files),
                "error": str(exc),
            },
        )
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    logger.info(
        "jira.issue.create_with_attachments.done",
        extra={
            "event": "jira.issue.create_with_attachments.done",
            "user": user,
            "ip": client_ip,
            "customer_part": customer_part,
            "req_type": req_type,
            "file_count": len(files),
            "issue_key": result.get("key"),
        },
    )
    return JiraIssueCreateResponse(**result)


@router.get("/field-options", response_model=JiraFieldOptionsResponse)
def get_field_options(request: Request):
    client_ip = request.client.host if request.client else "unknown"
    user = getattr(request.state, "username", "anonymous")
    customer_parts = fetch_options("customer_part")
    req_types = fetch_options("req_type")
    logger.info(
        "jira.field_options.read",
        extra={
            "event": "jira.field_options.read",
            "user": user,
            "ip": client_ip,
            "customer_part_count": len(customer_parts),
            "req_type_count": len(req_types),
        },
    )
    return JiraFieldOptionsResponse(
        customer_parts=customer_parts,
        req_types=req_types,
    )
