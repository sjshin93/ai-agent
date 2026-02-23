from pydantic import BaseModel


class DanjiRequest(BaseModel):
    action: str
    payload: dict
    # TODO: add auth, correlation_id, etc.


class DanjiResponse(BaseModel):
    status: str
    data: dict | None = None


class DanjiEvent(BaseModel):
    event_type: str
    payload: dict
    # TODO: add signature, timestamp, etc.


class DanjiEventAck(BaseModel):
    accepted: bool
