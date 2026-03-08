from datetime import datetime

from pydantic import BaseModel


class AdminUserItem(BaseModel):
    user_id: str
    provider: str
    provider_user_id: str
    role: str
    nickname: str
    created_at: datetime
    updated_at: datetime
    last_login_at: datetime


class AdminUserListResponse(BaseModel):
    users: list[AdminUserItem]


class AdminLogEntry(BaseModel):
    occurred_at: datetime
    user_id: str
    session_id: str
    method: str
    path: str
    status_code: int
    duration_ms: int
    client_ip: str
    user_agent: str


class AdminLogEntriesResponse(BaseModel):
    log_type: str
    entries: list[AdminLogEntry]


class AdminTrafficPoint(BaseModel):
    timestamp: datetime
    api_calls: int


class AdminStatsResponse(BaseModel):
    subscriber_count: int
    visitor_count: int
    api_call_count: int
    traffic: list[AdminTrafficPoint]
