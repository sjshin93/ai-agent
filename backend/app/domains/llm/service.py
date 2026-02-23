from app.domains.llm.client import LlmClient


class LlmService:
    def __init__(self, llm_client: LlmClient) -> None:
        self._llm = llm_client

    async def query(self, prompt: str, model: str | None = None) -> str:
        # TODO: add prompt templates, tool routing, etc.
        return await self._llm.query(prompt=prompt, model=model)
