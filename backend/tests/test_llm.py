from app.dependencies import get_llm_service


class _FakeLlmService:
    def query(self, prompt: str) -> str:
        return f"echo: {prompt}"


def test_llm_query(client):
    def _override():
        return _FakeLlmService()

    client.app.dependency_overrides[get_llm_service] = _override
    res = client.post("/llm/query", json={"prompt": "ping"})
    client.app.dependency_overrides.clear()

    assert res.status_code == 200
    assert res.json() == {"output": "echo: ping"}
