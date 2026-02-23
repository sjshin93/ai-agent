from pydantic import BaseModel


class JiraIssueCreateRequest(BaseModel):
    title: str
    description: str | None = None
    customer_part: str
    req_type: str


class JiraIssueCreateResponse(BaseModel):
    key: str
    url: str
    self: str


class JiraFieldOptionsResponse(BaseModel):
    customer_parts: list[str]
    req_types: list[str]
