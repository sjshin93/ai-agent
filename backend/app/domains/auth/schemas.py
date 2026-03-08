from pydantic import BaseModel


class MeResponse(BaseModel):
    authenticated: bool
    user_id: str | None = None
    nickname: str | None = None
    role: str | None = None


class LogoutResponse(BaseModel):
    ok: bool = True
