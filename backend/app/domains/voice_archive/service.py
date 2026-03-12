from __future__ import annotations

import hashlib
from datetime import datetime
from pathlib import Path, PurePosixPath
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

from app.core.session_manager import SessionManager
from app.domains.voice_archive.schemas import VoiceArchiveResponse

_KST = ZoneInfo("Asia/Seoul")


class VoiceArchiveDuplicateError(Exception):
    """Raised when same audio payload already exists globally."""


class VoiceArchiveService:
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

    async def archive_voice(
        self,
        *,
        person_id: str,
        audio_bytes: bytes,
        file_ext: str,
        tags: str,
        emotion: str | None,
        reference_text: str | None,
        stt_text: str | None,
        captured_at: datetime | None,
    ) -> VoiceArchiveResponse:
        entry_id: UUID = uuid4()
        sha256 = hashlib.sha256(audio_bytes).hexdigest()
        if await self._session_manager.voice_archive_exists_sha256(sha256):
            raise VoiceArchiveDuplicateError(
                "Voice archive already exists for this audio content."
            )

        ext = self._normalize_ext(file_ext)
        captured_kst = self._to_kst_naive(captured_at)
        created_kst = datetime.now(_KST).replace(tzinfo=None)
        date_prefix = (captured_kst or created_kst).date().isoformat()
        file_name = f"{date_prefix}-{entry_id}.{ext}"

        target_dir = self._archive_root / person_id / "voice" / "raw"
        target_dir.mkdir(parents=True, exist_ok=True)
        file_path = target_dir / file_name
        file_path.write_bytes(audio_bytes)

        storage_key = str(self._public_root.joinpath(person_id, "voice", "raw", file_name))
        row = await self._session_manager.insert_voice_archive(
            entry_id=entry_id,
            person_id=person_id,
            file_name=file_name,
            file_ext=ext,
            storage_key=storage_key,
            created_at=created_kst,
            sha256=sha256,
            captured_at=captured_kst,
            tags=tags.strip(),
            emotion=(emotion or "").strip() or None,
            reference_text=(reference_text or "").strip() or None,
            stt_text=(stt_text or "").strip() or None,
        )
        return VoiceArchiveResponse(**row)

    def _normalize_ext(self, ext: str) -> str:
        normalized = (ext or "").strip().lower().lstrip(".")
        if not normalized:
            return "wav"
        filtered = "".join(ch for ch in normalized if ch.isalnum())
        return filtered or "wav"

    def _to_kst_naive(self, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            return value
        return value.astimezone(_KST).replace(tzinfo=None)
