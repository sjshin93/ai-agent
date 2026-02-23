from pydantic import BaseModel


class LlmQueryRequest(BaseModel):
    prompt: str
    model: str | None = None
    # TODO: add temperature, context, etc.


class LlmQueryResponse(BaseModel):
    output: str
    # TODO: add tokens, usage, latency, etc.
