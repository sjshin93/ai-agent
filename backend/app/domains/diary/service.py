from __future__ import annotations

import hashlib
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from uuid import UUID, uuid4

from app.core.session_manager import SessionManager
from app.domains.diary.schemas import DiaryArchiveRequest, DiaryArchiveResponse


class DiaryDuplicateError(Exception):
    """Raised when a diary entry already exists for the person_id + sha256 pair."""


class DiaryService:
    def __init__(
        self,
        *,
        session_manager: SessionManager,
        archive_root: Path,
        public_root: str,
    ) -> None:
        self._session_manager = session_manager
        self._archive_root = archive_root
        self._public_root = PurePosixPath(public_root)
        self._archive_root.mkdir(parents=True, exist_ok=True)

    async def archive_diary(
        self,
        request: DiaryArchiveRequest,
        person_id: str,
    ) -> DiaryArchiveResponse:
        entry_id: UUID = request.id or uuid4()
        raw = request.raw_text
        sha256 = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        if await self._session_manager.diary_entry_exists(person_id, sha256):
            raise DiaryDuplicateError("Diary entry already exists for this content.")

        filename = f"{request.event_date.isoformat()}-{entry_id}.txt"
        target_dir = self._archive_root / person_id / "memory" / "raw"
        target_dir.mkdir(parents=True, exist_ok=True)
        file_path = target_dir / filename
        file_path.write_text(raw, encoding="utf-8")

        storage_path = str(
            self._public_root.joinpath(person_id, "memory", "raw", filename)
        )
        created_at = datetime.now(timezone.utc)
        row = await self._session_manager.insert_diary_entry(
            entry_id=entry_id,
            person_id=person_id,
            storage_path=storage_path,
            created_at=created_at,
            sha256=sha256,
            event_date=request.event_date,
            emotion_label=request.emotion_label,
            event_text=request.event_text,
            feeling_text=request.feeling_text,
            reason_text=request.reason_text,
            next_action_text=request.next_action_text,
        )
        return DiaryArchiveResponse(**row)
