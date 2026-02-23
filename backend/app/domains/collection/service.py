from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from pathlib import Path

from app.core.config import settings

logger = logging.getLogger(__name__)

_VAR_PATTERN = re.compile(r"{{\s*([\w.-]+)\s*}}")


@dataclass
class ParsedRequest:
    id: str
    name: str
    method: str
    url: str
    headers: dict[str, str]
    body: str | None
    params: list[str]
    defaults: dict[str, str]


class CollectionStore:
    def __init__(self) -> None:
        self._items: dict[str, ParsedRequest] = {}

    def load(self) -> None:
        path = _resolve_collection_path(settings.collection_path)
        if not path:
            logger.warning("Collection file not found; API list is empty")
            self._items = {}
            return
        try:
            raw = path.read_text(encoding="utf-8")
            data = json.loads(raw)
        except OSError as exc:
            logger.exception("Failed to read collection file: %s", exc)
            self._items = {}
            return
        except json.JSONDecodeError as exc:
            logger.exception("Invalid collection JSON: %s", exc)
            self._items = {}
            return

        defaults = _extract_collection_variables(data)
        items: dict[str, ParsedRequest] = {}
        for item in _flatten_items(data.get("item", []), [], []):
            parsed = _parse_item(item, defaults)
            if parsed:
                items[parsed.id] = parsed
        self._items = items
        logger.info("Loaded %s collection items from %s", len(items), path)

    def list_items(self) -> list[ParsedRequest]:
        return list(self._items.values())

    def get(self, item_id: str) -> ParsedRequest | None:
        return self._items.get(item_id)


_STORE = CollectionStore()


def load_collection() -> None:
    _STORE.load()


def list_collection_items() -> list[ParsedRequest]:
    return _STORE.list_items()


def get_collection_item(item_id: str) -> ParsedRequest | None:
    return _STORE.get(item_id)


def substitute(text: str, params: dict[str, str], defaults: dict[str, str]) -> str:
    def _replace(match: re.Match[str]) -> str:
        key = match.group(1)
        if key in params:
            return params[key]
        if key in defaults:
            return defaults[key]
        return match.group(0)

    return _VAR_PATTERN.sub(_replace, text)


def resolve_framework_url_for_site(site_id: int) -> str | None:
    ip = _resolve_danji_ip(site_id)
    if not ip:
        return None
    scheme = settings.danji_framework_scheme.lower().strip()
    if scheme not in {"http", "https"}:
        scheme = "https"
    return f"{scheme}://{ip}:{settings.danji_framework_port}"


def extract_params(*values: str | None) -> list[str]:
    seen: set[str] = set()
    params: list[str] = []
    for value in values:
        if not value:
            continue
        for match in _VAR_PATTERN.findall(value):
            if match not in seen:
                seen.add(match)
                params.append(match)
    return params


def _resolve_collection_path(value: str) -> Path | None:
    candidates: list[Path] = []
    if value:
        candidates.append(Path(value))
    candidates.append(Path.cwd() / "collection.json")
    candidates.append(Path("/app/collection.json"))
    if not value:
        candidates.append(Path.cwd() / "postman_collection.json")
    for candidate in candidates:
        path = candidate.expanduser()
        if path.is_file():
            return path
    return None


def _resolve_danji_ip(site_id: int) -> str | None:
    mapping = _load_danji_ip_map()
    return mapping.get(site_id)


def _resolve_danji_info_path(value: str) -> Path | None:
    candidates: list[Path] = []
    if value:
        candidates.append(Path(value))
    candidates.append(Path.cwd() / "info_danji.txt")
    candidates.append(Path("/app/info_danji.txt"))
    candidates.append(Path.cwd().parent / "info_danji.txt")
    for candidate in candidates:
        path = candidate.expanduser()
        if path.is_file():
            return path
    return None


def _load_danji_ip_map() -> dict[int, str]:
    path = _resolve_danji_info_path(settings.danji_info_path)
    if not path:
        logger.warning("info_danji.txt not found; siteId IP mapping unavailable")
        return {}
    mapping: dict[int, str] = {}
    try:
        for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = raw.strip()
            if not line or not line.startswith("id:"):
                continue
            fields: dict[str, str] = {}
            for part in line.split("|"):
                if ":" not in part:
                    continue
                key, value = part.split(":", 1)
                fields[key.strip()] = value.strip()
            site_raw = fields.get("id", "")
            ip_raw = fields.get("ip", "")
            if not site_raw or not ip_raw:
                continue
            ip_lower = ip_raw.lower()
            if ip_lower in {"none", "null"}:
                continue
            try:
                site_id = int(site_raw)
            except ValueError:
                continue
            mapping[site_id] = ip_raw
    except OSError as exc:
        logger.exception("Failed to read info_danji.txt %s: %s", path, exc)
        return {}
    return mapping


def _extract_collection_variables(data: dict) -> dict[str, str]:
    defaults: dict[str, str] = {}
    for item in data.get("variable", []) or []:
        key = str(item.get("key", "")).strip()
        value = str(item.get("value", "")).strip()
        if key:
            defaults[key] = value
    if settings.collection_base_url:
        defaults.setdefault("baseUrl", settings.collection_base_url)
        defaults.setdefault("base_url", settings.collection_base_url)
    defaults.setdefault("bds-core-framework-url", "https://172.20.200.200:30001")
    return defaults


def _flatten_items(items: list, name_parts: list[str], idx_parts: list[str]):
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or f"item-{idx}")
        if "item" in item and "request" not in item:
            yield from _flatten_items(
                item.get("item", []),
                name_parts + [name],
                idx_parts + [str(idx)],
            )
            continue
        if "request" in item:
            item = dict(item)
            item["_name_parts"] = name_parts + [name]
            item["_idx_parts"] = idx_parts + [str(idx)]
            yield item


def _parse_item(item: dict, defaults: dict[str, str]) -> ParsedRequest | None:
    request = item.get("request")
    if not isinstance(request, dict):
        return None
    method = str(request.get("method", "GET")).upper()
    url_raw = _parse_url(request.get("url"))
    if not url_raw:
        return None
    headers = _parse_headers(request.get("header", []))
    body = _parse_body(request.get("body"))
    name_parts = item.get("_name_parts", [])
    name = " / ".join(name_parts) if name_parts else str(item.get("name", ""))
    idx_parts = item.get("_idx_parts", [])
    item_id = ".".join(idx_parts) if idx_parts else name

    combined_defaults = dict(defaults)
    url_value = request.get("url")
    if isinstance(url_value, dict):
        for var in url_value.get("variable", []) or []:
            key = str(var.get("key", "")).strip()
            value = str(var.get("value", "")).strip()
            if key and value:
                combined_defaults.setdefault(key, value)

    params = extract_params(url_raw, body)
    return ParsedRequest(
        id=item_id,
        name=name,
        method=method,
        url=url_raw,
        headers=headers,
        body=body,
        params=params,
        defaults=combined_defaults,
    )


def _parse_url(value) -> str:
    if isinstance(value, str):
        return value
    if not isinstance(value, dict):
        return ""
    raw = value.get("raw")
    if isinstance(raw, str) and raw:
        return raw
    protocol = value.get("protocol", "")
    host = value.get("host")
    if isinstance(host, list):
        host = ".".join(host)
    path = value.get("path")
    if isinstance(path, list):
        path = "/".join(path)
    query = value.get("query")
    query_str = ""
    if isinstance(query, list) and query:
        pairs = []
        for item in query:
            if not isinstance(item, dict):
                continue
            key = str(item.get("key", "")).strip()
            val = str(item.get("value", "")).strip()
            if not key:
                continue
            pairs.append(f"{key}={val}")
        if pairs:
            query_str = "?" + "&".join(pairs)
    base = ""
    if protocol and host:
        base = f"{protocol}://{host}"
    elif host:
        base = host
    if path:
        return f"{base}/{path}{query_str}" if base else f"/{path}{query_str}"
    return f"{base}{query_str}" if base else ""


def _parse_headers(value) -> dict[str, str]:
    headers: dict[str, str] = {}
    if not isinstance(value, list):
        return headers
    for item in value:
        if not isinstance(item, dict):
            continue
        if item.get("disabled") is True:
            continue
        key = str(item.get("key", "")).strip()
        val = str(item.get("value", "")).strip()
        if key:
            headers[key] = val
    return headers


def _parse_body(value) -> str | None:
    if not isinstance(value, dict):
        return None
    mode = value.get("mode")
    if mode != "raw":
        return None
    raw = value.get("raw")
    if isinstance(raw, str):
        return raw
    return None
