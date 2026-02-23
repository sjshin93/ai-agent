from app.core.http import HttpClient, HttpRetryConfig


class JiraClient:
    def __init__(self, base_url: str, email: str, api_token: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._auth = (email, api_token)
        self._http = HttpClient(timeout=10, retry=HttpRetryConfig(retries=1))

    async def create_issue(self, payload: dict) -> dict:
        url = f"{self._base_url}/rest/api/3/issue"
        res = await self._http.request(
            "POST",
            url,
            json=payload,
            headers={"Accept": "application/json"},
            auth=self._auth,
        )
        if res.status_code >= 400:
            raise RuntimeError(
                f"Jira create issue failed: {res.status_code} {res.text}"
            )
        return res.json()

    async def add_attachments(
        self,
        issue_key: str,
        files: list[tuple[str, bytes, str]],
    ) -> list[dict]:
        url = f"{self._base_url}/rest/api/3/issue/{issue_key}/attachments"
        multipart = []
        for filename, content, content_type in files:
            multipart.append(
                (
                    "file",
                    (filename, content, content_type or "application/octet-stream"),
                )
            )
        http = HttpClient(timeout=30, retry=HttpRetryConfig(retries=1))
        res = await http.request(
            "POST",
            url,
            files=multipart,
            headers={
                "Accept": "application/json",
                "X-Atlassian-Token": "no-check",
            },
            auth=self._auth,
        )
        if res.status_code >= 400:
            raise RuntimeError(
                f"Jira attachment failed: {res.status_code} {res.text}"
            )
        data = res.json()
        if isinstance(data, list):
            return data
        return []
