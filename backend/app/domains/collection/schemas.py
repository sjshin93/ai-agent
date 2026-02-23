from pydantic import BaseModel


class CollectionItem(BaseModel):
    id: str
    name: str
    method: str
    url: str
    params: list[str]
    body: str | None = None


class CollectionListResponse(BaseModel):
    items: list[CollectionItem]


class CollectionExecuteRequest(BaseModel):
    id: str
    params: dict[str, str] = {}
    site_id: int | None = None
    body: str | None = None
    access_token: str | None = None
    verify_ssl: bool = True
    log_request: bool = True


class CollectionExecuteResponse(BaseModel):
    status_code: int
    url: str
    headers: dict[str, str]
    body: str
