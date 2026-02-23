from app.core.http import HttpClient, HttpRetryConfig


class SlackClient:
    def __init__(self, webhook_url: str) -> None:
        self._webhook_url = webhook_url
        self._http = HttpClient(timeout=5, retry=HttpRetryConfig(retries=1))

    async def send_message(self, message: str) -> None:
        if not self._webhook_url:
            raise RuntimeError("SLACK_WEBHOOK_URL not configured")
        payload = {"text": message}
        res = await self._http.request("POST", self._webhook_url, json=payload)
        if res.status_code >= 400:
            raise RuntimeError(f"Slack webhook error: {res.status_code}")
