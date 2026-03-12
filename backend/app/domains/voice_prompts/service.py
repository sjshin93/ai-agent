from __future__ import annotations

import csv
import re
from pathlib import Path

from app.domains.voice_prompts.schemas import (
    VoicePromptCategory,
    VoicePromptItem,
)


class VoicePromptLoadError(RuntimeError):
    pass


class VoicePromptService:
    _version_pattern = re.compile(r"_v(\d+)\.csv$", re.IGNORECASE)

    def __init__(self, archive_root: Path) -> None:
        self._voice_root = archive_root / "voice_features"

    def load(self, category: VoicePromptCategory) -> list[VoicePromptItem]:
        source = self._resolve_source_file(category)
        rows: list[VoicePromptItem] = []
        with source.open("r", encoding="utf-8-sig", newline="") as fp:
            reader = csv.DictReader(fp, delimiter="|")
            for row in reader:
                item = VoicePromptItem(
                    id=(row.get("id") or "").strip(),
                    version=(row.get("version") or "").strip(),
                    type=(row.get("type") or category).strip(),
                    emotion_level=self._optional(row.get("emotion_level")),
                    emotion_intensity=self._optional(row.get("emotion_intensity")),
                    direction=(row.get("direction") or "").strip(),
                    text=(row.get("text") or "").strip(),
                )
                if item.id and item.direction and item.text:
                    rows.append(item)
        return rows

    def _resolve_source_file(self, category: VoicePromptCategory) -> Path:
        candidates = sorted(self._voice_root.glob(f"{category}*.csv"))
        if not candidates:
            raise VoicePromptLoadError(
                f"CSV not found for category '{category}' under {self._voice_root}"
            )
        return max(candidates, key=self._file_version)

    def _file_version(self, file: Path) -> int:
        match = self._version_pattern.search(file.name)
        if not match:
            return 0
        return int(match.group(1))

    @staticmethod
    def _optional(value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None
