from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class VoiceArchiveResponse(BaseModel):
    id: UUID
    person_id: str
    file_name: str
    file_ext: str
    storage_key: str
    created_at: datetime
    sha256: str
    captured_at: datetime | None = None
    tags: str
    emotion: str | None = None
    reference_text: str | None = None
    stt_text: str | None = None


class VoiceArchiveDeleteResponse(BaseModel):
    deleted: bool
    storage_key: str


class VoiceArchiveBulkDeleteResponse(BaseModel):
    deleted_count: int
    tags: str
