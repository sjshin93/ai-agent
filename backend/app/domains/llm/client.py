from app.core.http import HttpClient, HttpRetryConfig


class LlmClient:
    def __init__(
        self,
        base_url: str,
        api_key: str,
        chat_path: str,
        default_model: str,
        gemini_api_key: str = "",
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._chat_path = chat_path
        self._default_model = default_model
        self._gemini_api_key = gemini_api_key
        self._http = HttpClient(timeout=30, retry=HttpRetryConfig(retries=1))

    async def query(self, prompt: str, model: str | None = None) -> str:
        if self._gemini_api_key:
            return await self._query_gemini(prompt=prompt, model=model)
        return await self._query_openwebui(prompt=prompt, model=model)

    async def _query_openwebui(self, prompt: str, model: str | None = None) -> str:
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

    async def _query_gemini(self, prompt: str, model: str | None = None) -> str:
        target_model = (model or "gemini-flash-latest").strip()
        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{target_model}:generateContent?key={self._gemini_api_key}"
        )
        payload = {
            "contents": [
                {
                    "parts": [{"text": prompt}],
                }
            ]
        }
        headers = {"Content-Type": "application/json"}
        res = await self._http.request("POST", url, json=payload, headers=headers)
        if res.status_code != 200:
            raise RuntimeError(f"Gemini error: {res.status_code} {res.text}")
        data = res.json()
        candidates = data.get("candidates") or []
        if not candidates:
            raise RuntimeError("Gemini returned no candidates")
        content = candidates[0].get("content") or {}
        parts = content.get("parts") or []
        texts: list[str] = []
        for part in parts:
            text = str((part or {}).get("text") or "").strip()
            if text:
                texts.append(text)
        if not texts:
            raise RuntimeError("Gemini returned empty content")
        return "\n".join(texts)
