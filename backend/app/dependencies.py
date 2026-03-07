from app.core.config import settings
from app.domains.jira.client import JiraClient
from app.domains.jira.service import JiraService
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


def get_jira_client() -> JiraClient:
    if not settings.jira_base_url:
        raise RuntimeError("JIRA_BASE_URL not configured")
    if not settings.jira_email or not settings.jira_api_token:
        raise RuntimeError("JIRA_EMAIL or JIRA_API_TOKEN not configured")
    return JiraClient(
        base_url=settings.jira_base_url,
        email=settings.jira_email,
        api_token=settings.jira_api_token,
    )


def get_jira_service() -> JiraService:
    return JiraService(
        jira_client=get_jira_client(),
        base_url=settings.jira_base_url,
        project_key=settings.jira_project_key,
        issue_type=settings.jira_issue_type,
        customer_part_field_id=settings.jira_customer_part_field_id,
        req_type_field_id=settings.jira_req_type_field_id,
    )

def get_ssh_service() -> SshService:
    return SshService()


def get_session_manager() -> SessionManager:
    return session_manager
