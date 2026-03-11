from pydantic import BaseModel


class AutoLogoutConfigResponse(BaseModel):
    auto_logout_seconds: int


class VersionConfigResponse(BaseModel):
    version: str


class SessionTouchResponse(BaseModel):
    ok: bool


class TurnstileConfigResponse(BaseModel):
    enabled: bool
    site_key: str | None = None
