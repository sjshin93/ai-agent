from app.domains.danji.client import DanjiClient


class DanjiService:
    def __init__(self, danji_client: DanjiClient) -> None:
        self._danji = danji_client

    def send_request(self, action: str, payload: dict) -> dict:
        # TODO: add auth headers, retries, etc.
        return self._danji.send_request(action=action, payload=payload)

    def handle_event(self, event_type: str, payload: dict) -> None:
        # TODO: route event to domain logic.
        raise NotImplementedError("DanjiService.handle_event is not implemented yet.")
