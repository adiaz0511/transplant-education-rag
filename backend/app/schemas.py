from pydantic import BaseModel


class QueryRequest(BaseModel):
    query: str


class TopicRequest(BaseModel):
    topic: str
    instructions: str | None = None
