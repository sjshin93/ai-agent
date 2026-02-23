from pydantic import BaseModel, Field


class DjOauthLoginRequest(BaseModel):
    user_id: str = Field(
        validation_alias="userId",
        serialization_alias="userId",
    )
    password: str

    model_config = {"populate_by_name": True}


class DjOauthLoginResponse(BaseModel):
    ok: bool
    detail: str | None = None
    access_token: str | None = None


class DjOauthHouseholdRequest(BaseModel):
    site_id: int = Field(
        validation_alias="siteId",
        serialization_alias="siteId",
    )
    dong: str
    ho: str
    nickname: str

    model_config = {"populate_by_name": True}


class DjOauthHouseholdResponse(BaseModel):
    ok: bool
    detail: str | None = None
    data: dict | list | str | None = None


class DjOauthLogoutRequest(BaseModel):
    user_id: str


class DjOauthLogoutResponse(BaseModel):
    ok: bool
