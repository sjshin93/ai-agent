import logging
import os
from pathlib import Path


logger = logging.getLogger(__name__)


def _load_kv_file(path: Path, warn_missing: bool) -> dict[str, str]:
    data: dict[str, str] = {}
    try:
        if not path.exists():
            if warn_missing:
                logger.warning("Config file not found: %s", path)
            return data
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                logger.warning("Invalid config line (missing '='): %s", line)
                continue
            key, value = line.split("=", 1)
            data[key.strip()] = value.strip()
    except OSError as exc:
        logger.exception("Failed to read config file %s: %s", path, exc)
    return data


_BASE_DIR = Path(__file__).resolve().parents[2]
_CONFIG_PATH_ENV = os.getenv("CONFIG_PATH")
_EXPLICIT_CONFIG = _CONFIG_PATH_ENV is not None
_CONFIG_PATH = Path(_CONFIG_PATH_ENV) if _EXPLICIT_CONFIG else _BASE_DIR / "config.env"
_FILE_VALUES = _load_kv_file(_CONFIG_PATH, warn_missing=_EXPLICIT_CONFIG)


def _get(key: str, default: str = "") -> str:
    return os.getenv(key, _FILE_VALUES.get(key, default))


def _get_log_level() -> str:
    value = _get("LOG_LEVEL", "info").lower()
    allowed = {"debug", "info", "notice", "warn", "warning", "error", "crit", "alert", "emerg"}
    if value == "warning":
        return "warn"
    if value not in allowed:
        logger.warning("Invalid LOG_LEVEL '%s', falling back to 'info'", value)
        return "info"
    return value


def _get_int(key: str, default: int) -> int:
    value = _get(key, str(default))
    try:
        return int(value)
    except ValueError:
        logger.warning("Invalid %s '%s', falling back to %s", key, value, default)
        return default


def _get_bool(key: str, default: bool) -> bool:
    value = _get(key, "true" if default else "false").strip().lower()
    if value in {"1", "true", "t", "yes", "y", "on"}:
        return True
    if value in {"0", "false", "f", "no", "n", "off"}:
        return False
    logger.warning("Invalid %s '%s', falling back to %s", key, value, default)
    return default


def _get_csv(key: str, default: str = "") -> list[str]:
    value = _get(key, default)
    result: list[str] = []
    for raw in value.split(","):
        item = raw.strip()
        if item:
            result.append(item)
    return result


class Settings:
    # TODO: swap to pydantic-settings if you want validation.
    slack_webhook_url: str = _get("SLACK_WEBHOOK_URL", "")

    llm_base_url: str = _get("LLM_BASE_URL", "http://llm:8001")
    llm_api_key: str = _get("LLM_API_KEY", "")
    gemini_api_key: str = _get("GEMINI_API_KEY", "")
    openwebui_base_url: str = _get("OPENWEBUI_BASE_URL", "")
    openwebui_api_key: str = _get("OPENWEBUI_API_KEY", "")
    openwebui_chat_path: str = _get("OPENWEBUI_CHAT_PATH", "/v1/chat/completions")
    openwebui_default_model: str = _get("OPENWEBUI_DEFAULT_MODEL", "")

    server_host: str = _get("SERVER_HOST", "0.0.0.0")
    server_port: int = int(_get("SERVER_PORT", "8000"))
    log_level: str = _get_log_level()
    version: str = _get("VERSION", "0.0.0")
    auto_logout_seconds: int = _get_int("AUTO_LOGOUT_SECONDS", 300)
    session_cleanup_interval_seconds: int = _get_int(
        "SESSION_CLEANUP_INTERVAL_SECONDS",
        5 * 60,
    )
    session_retention_seconds: int = _get_int(
        "SESSION_RETENTION_SECONDS",
        14 * 24 * 60 * 60,
    )
    postgres_dsn: str = _get(
        "POSTGRES_DSN",
        "postgresql://app:app@postgres:5432/app",
    )
    postgres_pool_min_size: int = _get_int("POSTGRES_POOL_MIN_SIZE", 1)
    postgres_pool_max_size: int = _get_int("POSTGRES_POOL_MAX_SIZE", 10)
    redis_url: str = _get("REDIS_URL", "redis://redis:6379/0")
    session_cookie_name: str = _get("SESSION_COOKIE_NAME", "session_id")
    session_cookie_secure: bool = _get_bool("SESSION_COOKIE_SECURE", False)
    oauth_token_url: str = _get("OAUTH_TOKEN_URL", "")
    google_client_id: str = _get("GOOGLE_CLIENT_ID", "")
    google_client_secret: str = _get("GOOGLE_CLIENT_SECRET", "")
    google_redirect_uri: str = _get(
        "GOOGLE_REDIRECT_URI",
        "http://localhost:8080/api/auth/google/callback",
    )
    google_success_redirect: str = _get("GOOGLE_SUCCESS_REDIRECT", "/login?google=ok")
    google_failure_redirect: str = _get("GOOGLE_FAILURE_REDIRECT", "/login?google=error")
    kakao_rest_api_key: str = _get("KAKAO_REST_API_KEY", "")
    kakao_client_secret: str = _get("KAKAO_CLIENT_SECRET", "")
    kakao_redirect_uri: str = _get(
        "KAKAO_REDIRECT_URI",
        "http://localhost:8080/api/auth/kakao/callback",
    )
    kakao_success_redirect: str = _get("KAKAO_SUCCESS_REDIRECT", "/login?kakao=ok")
    kakao_failure_redirect: str = _get("KAKAO_FAILURE_REDIRECT", "/login?kakao=error")
    admin_user_ids: list[str] = _get_csv(
        "ADMIN_USER_IDS",
        "kakao_4784641296,google_112479972436700768040",
    )
    collection_path: str = _get("COLLECTION_PATH", "")
    collection_base_url: str = _get("COLLECTION_BASE_URL", "")
    collection_log_path: str = _get("COLLECTION_LOG_PATH", "data/api_test.log")
    aws_ssh_host: str = _get("AWS_SSH_HOST", "")
    aws_ssh_port: int = _get_int("AWS_SSH_PORT", 22)
    aws_ssh_user: str = _get("AWS_SSH_USER", "")
    aws_ssh_key_path: str = _get("AWS_SSH_KEY_PATH", "")
    aws_ssh_aliases_path: str = _get("AWS_SSH_ALIASES_PATH", "~/.bash_aliases")
    ssh_target_password: str = _get("SSH_TARGET_PASSWORD", "")

    jira_base_url: str = _get("JIRA_BASE_URL", "")
    jira_email: str = _get("JIRA_EMAIL", "")
    jira_api_token: str = _get("JIRA_API_TOKEN", "")
    jira_project_key: str = _get("JIRA_PROJECT_KEY", "TS")
    jira_issue_type: str = _get("JIRA_ISSUE_TYPE", "Task")
    jira_customer_part_field_id: str = _get(
        "JIRA_CUSTOMER_PART_FIELD_ID", "customfield_10046"
    )
    jira_req_type_field_id: str = _get(
        "JIRA_REQ_TYPE_FIELD_ID", "customfield_10047"
    )
    http_timeout: float = float(_get("HTTP_TIMEOUT", "5"))
    http_retry: int = _get_int("HTTP_RETRY", 3)


settings = Settings()
