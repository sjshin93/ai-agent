from app.core.config import settings
from pathlib import Path

from app.domains.diary.service import DiaryService
from app.domains.llm.client import LlmClient
from app.domains.llm.service import LlmService
from app.domains.slack_notification.client import SlackClient
from app.domains.slack_notification.service import SlackNotificationService
from app.domains.ssh.service import SshService
from app.core.session_manager import SessionManager
from app.core.session_state import session_manager


def get_slack_client() -> SlackClient:
    return SlackClient(webhook_url=settings.slack_webhook_url)


def get_llm_client() -> LlmClient:
    return LlmClient(
        base_url=settings.openwebui_base_url or settings.llm_base_url,
        api_key=settings.openwebui_api_key or settings.llm_api_key,
        chat_path=settings.openwebui_chat_path,
        default_model=settings.openwebui_default_model,
        gemini_api_key=settings.gemini_api_key,
    )


def get_slack_notification_service() -> SlackNotificationService:
    return SlackNotificationService(slack_client=get_slack_client())


def get_llm_service() -> LlmService:
    return LlmService(llm_client=get_llm_client())

def get_diary_service() -> DiaryService:
    archive_root = Path(settings.archive_root_path).expanduser()
    return DiaryService(
        session_manager=get_session_manager(),
        archive_root=archive_root,
        public_root=settings.archive_public_path,
    )

def get_ssh_service() -> SshService:
    return SshService()


def get_session_manager() -> SessionManager:
    return session_manager
