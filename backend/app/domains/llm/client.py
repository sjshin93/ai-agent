from app.core.http import HttpClient, HttpRetryConfig


class LlmClient:
    def __init__(self, base_url: str, api_key: str, chat_path: str, default_model: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._chat_path = chat_path
        self._default_model = default_model
        self._http = HttpClient(timeout=30, retry=HttpRetryConfig(retries=1))

    async def query(self, prompt: str, model: str | None = None) -> str:
        if not self._base_url:
            raise RuntimeError("OPENWEBUI_BASE_URL not configured")
        headers = {"Content-Type": "application/json"}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"
        url = f"{self._base_url}{self._chat_path}"
        payload = {
            "model": model or self._default_model or "gpt-3.5-turbo",
            "messages": [{"role": "user", "content": prompt}],
        }
        res = await self._http.request("POST", url, json=payload, headers=headers)
        if res.status_code != 200:
            raise RuntimeError(f"LLM error: {res.status_code} {res.text}")
        data = res.json()
        return data["choices"][0]["message"]["content"]
