import json
import logging
from datetime import datetime, timezone
from pathlib import Path

from app.core.config import settings

logger = logging.getLogger(__name__)

_MAX_BODY = 20000


def _truncate(value: str | None) -> tuple[str | None, bool]:
    if value is None:
        return None, False
    if len(value) <= _MAX_BODY:
        return value, False
    return value[:_MAX_BODY], True


def log_request_response(payload: dict) -> None:
    path = Path(settings.collection_log_path)
    if not path.is_absolute():
        path = Path.cwd() / path
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        logger.warning("Failed to create log dir %s: %s", path.parent, exc)
        return

    try:
        entry = dict(payload)
        entry["timestamp"] = datetime.now(timezone.utc).isoformat()
        if "request_body" in entry:
            entry["request_body"], entry["request_body_truncated"] = _truncate(
                entry.get("request_body")
            )
        if "response_body" in entry:
            entry["response_body"], entry["response_body_truncated"] = _truncate(
                entry.get("response_body")
            )
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False))
            f.write("\n")
    except OSError as exc:
        logger.warning("Failed to write log %s: %s", path, exc)
