from pydantic import BaseModel


class HtOauthLoginRequest(BaseModel):
    username: str
    password: str


class HtOauthLoginResponse(BaseModel):
    ok: bool
    access_token: str | None = None
    detail: str | None = None


class HtOauthLogoutRequest(BaseModel):
    username: str


class HtOauthLogoutResponse(BaseModel):
    ok: bool


class HtOauthRebootRequest(BaseModel):
    site_id: int
    dong: int
    ho: int


class HtOauthRebootResponse(BaseModel):
    ok: bool
    error_type: str | None = None
    detail: str | None = None
    data: dict | list | str | None = None
