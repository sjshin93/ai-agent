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
