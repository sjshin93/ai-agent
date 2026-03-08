from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from app.core.config import settings
from app.dependencies import get_session_manager
from app.core.session_manager import SessionManager
from app.domains.admin.schemas import (
    AdminLogEntriesResponse,
    AdminLogEntry,
    AdminStatsResponse,
    AdminTrafficPoint,
    AdminUserItem,
    AdminUserListResponse,
)

router = APIRouter()

LogType = Literal["system", "api", "error"]


async def _require_admin_access(
    request: Request,
    sessions: SessionManager,
) -> str:
    session_id = request.cookies.get(settings.session_cookie_name)
    user_id = await sessions.validate_and_touch(session_id) if session_id else None
    if not user_id:
        raise HTTPException(status_code=401, detail="Authentication required")

    role = await sessions.get_user_role(str(user_id))
    if role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return str(user_id)


@router.get("/users", response_model=AdminUserListResponse)
async def list_users(
    request: Request,
    sessions: SessionManager = Depends(get_session_manager),
):
    await _require_admin_access(request, sessions)
    rows = await sessions.list_users()
    return AdminUserListResponse(
        users=[AdminUserItem(**row) for row in rows],
    )


@router.get("/logs", response_model=AdminLogEntriesResponse)
async def fetch_logs(
    request: Request,
    log_type: LogType = Query("system", alias="type"),
    limit: int = Query(80, ge=1, le=200),
    sessions: SessionManager = Depends(get_session_manager),
):
    await _require_admin_access(request, sessions)
    rows = await sessions.fetch_user_activity_logs(log_type=log_type, limit=limit)
    return AdminLogEntriesResponse(
        log_type=log_type,
        entries=[AdminLogEntry(**row) for row in rows],
    )


@router.get("/stats", response_model=AdminStatsResponse)
async def fetch_stats(
    request: Request,
    sessions: SessionManager = Depends(get_session_manager),
    visitor_hours: int = Query(24, ge=1, le=168),
    traffic_hours: int = Query(12, ge=1, le=72),
):
    await _require_admin_access(request, sessions)
    now = datetime.now(timezone.utc)
    visitor_since = now - timedelta(hours=visitor_hours)
    subscriber_count = await sessions.count_users()
    visitor_count = await sessions.count_unique_visitors_since(visitor_since)
    api_call_count = await sessions.count_api_calls_since(visitor_since)

    end_bucket = now.replace(minute=0, second=0, microsecond=0)
    start_bucket = end_bucket - timedelta(hours=traffic_hours - 1)
    traffic_rows = await sessions.aggregate_api_calls_by_hour(since=start_bucket)
    counts = {
        row["bucket"]: row["count"]
        for row in traffic_rows
    }
    points: list[AdminTrafficPoint] = []
    cursor = start_bucket
    for _ in range(traffic_hours):
        points.append(
            AdminTrafficPoint(
                timestamp=cursor,
                api_calls=counts.get(cursor, 0),
            ),
        )
        cursor += timedelta(hours=1)

    return AdminStatsResponse(
        subscriber_count=subscriber_count,
        visitor_count=visitor_count,
        api_call_count=api_call_count,
        traffic=points,
    )
