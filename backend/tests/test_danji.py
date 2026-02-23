from app.dependencies import get_danji_service


class _FakeDanjiService:
    def __init__(self) -> None:
        self.events = []

    def send_request(self, action: str, payload: dict) -> dict:
        return {"action": action, "payload": payload}

    def handle_event(self, event_type: str, payload: dict) -> None:
        self.events.append((event_type, payload))


def test_danji_request(client):
    fake_service = _FakeDanjiService()

    def _override():
        return fake_service

    client.app.dependency_overrides[get_danji_service] = _override
    res = client.post(
        "/danji/request",
        json={"action": "sync", "payload": {"id": 1}},
    )
    client.app.dependency_overrides.clear()

    assert res.status_code == 200
    assert res.json() == {"status": "ok", "data": {"action": "sync", "payload": {"id": 1}}}


def test_danji_event(client):
    fake_service = _FakeDanjiService()

    def _override():
        return fake_service

    client.app.dependency_overrides[get_danji_service] = _override
    res = client.post(
        "/danji/events",
        json={"event_type": "updated", "payload": {"id": 1}},
    )
    client.app.dependency_overrides.clear()

    assert res.status_code == 200
    assert res.json() == {"accepted": True}
    assert fake_service.events == [("updated", {"id": 1})]
