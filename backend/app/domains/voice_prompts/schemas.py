from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

VoicePromptCategory = Literal["timbre", "prosody", "emotion"]


class VoicePromptItem(BaseModel):
    id: str
    version: str
    type: str
    is_archived: bool = False
    emotion_level: str | None = None
    emotion_intensity: str | None = None
    direction: str
    text: str


class VoicePromptListResponse(BaseModel):
    category: VoicePromptCategory
    count: int
    items: list[VoicePromptItem]
