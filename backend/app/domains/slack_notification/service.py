from app.domains.slack_notification.client import SlackClient


class SlackNotificationService:
    def __init__(self, slack_client: SlackClient) -> None:
        self._slack = slack_client

    async def send_slack_notification(self, message: str) -> None:
        # TODO: add formatting, routing rules, retries, etc.
        await self._slack.send_message(message=message)
