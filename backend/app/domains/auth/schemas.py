from pydantic import BaseModel


class MeResponse(BaseModel):
    authenticated: bool
    username: str | None = None


class LogoutResponse(BaseModel):
    ok: bool = True
