class DanjiClient:
    def __init__(self, base_url: str) -> None:
        self._base_url = base_url

    def send_request(self, action: str, payload: dict) -> dict:
        # TODO: call Danji server via HTTP/gRPC.
        raise NotImplementedError("DanjiClient.send_request is not implemented yet.")
