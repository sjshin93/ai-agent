from pydantic import BaseModel


class SlackNotificationRequest(BaseModel):
    message: str
    # TODO: add username, icon, attachments, etc.


class SlackNotificationResponse(BaseModel):
    ok: bool
    # TODO: add ts, channel, error, etc.
