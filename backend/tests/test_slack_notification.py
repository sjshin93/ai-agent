from app.dependencies import get_slack_notification_service


class _FakeSlackNotificationService:
    def __init__(self) -> None:
        self.sent = []

    async def send_slack_notification(self, message: str) -> None:
        self.sent.append(message)


def test_slack_notification(client):
    fake_service = _FakeSlackNotificationService()

    def _override():
        return fake_service

    client.app.dependency_overrides[get_slack_notification_service] = _override
    res = client.post("/slack-notification/slack", json={"message": "hello"})
    client.app.dependency_overrides.clear()

    assert res.status_code == 200
    assert res.json() == {"ok": True}
    assert fake_service.sent == ["hello"]
