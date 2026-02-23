from pydantic import BaseModel


class SshTopRequest(BaseModel):
    site_id: str
    command: str | None = None
    username: str | None = None


class SshTopResponse(BaseModel):
    output: str
