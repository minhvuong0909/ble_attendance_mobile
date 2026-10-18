from pydantic import BaseModel, ConfigDict

from app.schemas.common import UtcDateTime


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    type: str
    title: str
    body: str
    ref_id: str | None
    is_read: bool
    created_at: UtcDateTime
