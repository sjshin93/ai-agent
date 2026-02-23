from fastapi import UploadFile

from app.domains.jira.client import JiraClient


class JiraService:
    def __init__(
        self,
        jira_client: JiraClient,
        base_url: str,
        project_key: str,
        issue_type: str,
        customer_part_field_id: str,
        req_type_field_id: str,
    ) -> None:
        self._client = jira_client
        self._base_url = base_url.rstrip("/")
        self._project_key = project_key
        self._issue_type = issue_type
        self._customer_part_field_id = customer_part_field_id
        self._req_type_field_id = req_type_field_id

    def _to_adf(self, text: str | None) -> dict:
        if not text:
            return {"type": "doc", "version": 1, "content": []}
        paragraphs = []
        for line in text.splitlines() or [""]:
            paragraphs.append(
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": line}],
                }
            )
        return {"type": "doc", "version": 1, "content": paragraphs}

    async def create_task(
        self,
        title: str,
        description: str | None,
        customer_part: str,
        req_type: str,
    ) -> dict:
        payload = {
            "fields": {
                "project": {"key": self._project_key},
                "issuetype": {"name": self._issue_type},
                "summary": title,
                "description": self._to_adf(description),
                self._customer_part_field_id: {"value": customer_part},
                self._req_type_field_id: {"value": req_type},
            }
        }
        result = await self._client.create_issue(payload)
        key = result.get("key", "")
        return {
            "key": key,
            "self": result.get("self", ""),
            "url": f"{self._base_url}/browse/{key}" if key else "",
        }

    async def create_task_with_attachments(
        self,
        title: str,
        description: str | None,
        customer_part: str,
        req_type: str,
        files: list[UploadFile],
    ) -> dict:
        result = await self.create_task(
            title=title,
            description=description,
            customer_part=customer_part,
            req_type=req_type,
        )
        key = result.get("key", "")
        if key and files:
            attachments: list[tuple[str, bytes, str]] = []
            for file in files:
                content = await file.read()
                if not content:
                    continue
                content_type = file.content_type or "application/octet-stream"
                attachments.append((file.filename, content, content_type))
            if attachments:
                await self._client.add_attachments(key, attachments)
        return result
