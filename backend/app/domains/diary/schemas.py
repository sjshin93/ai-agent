from __future__ import annotations

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

EmotionLabel = Literal[
    "joy",
    "happy",
    "excited",
    "grateful",
    "calm",
    "hopeful",
    "proud",
    "loved",
    "sad",
    "lonely",
    "disappointed",
    "regretful",
    "ashamed",
    "angry",
    "frustrated",
    "annoyed",
    "anxious",
    "afraid",
    "stressed",
    "confused",
]


class DiaryArchiveRequest(BaseModel):
    id: UUID | None = None
    person_id: str | None = None
    event_date: date
    raw_text: str = Field(..., min_length=1)
    emotion_label: EmotionLabel | None = None
    event_text: str | None = None
    feeling_text: str | None = None
    reason_text: str | None = None
    next_action_text: str | None = None

    @model_validator(mode="after")
    def ensure_raw_text(cls, values: "DiaryArchiveRequest") -> "DiaryArchiveRequest":
        raw = values.raw_text
        if not isinstance(raw, str) or not raw.strip():
            raise ValueError("raw_text is required")
        return values


class DiaryArchiveResponse(BaseModel):
    id: UUID
    person_id: str
    storage_path: str
    created_at: datetime
    sha256: str
    event_date: date
    emotion_label: EmotionLabel | None = None
    event_text: str | None = None
    feeling_text: str | None = None
    reason_text: str | None = None
    next_action_text: str | None = None
