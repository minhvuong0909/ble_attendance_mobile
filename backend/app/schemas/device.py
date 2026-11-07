from pydantic import BaseModel, Field

from app.models import DeviceRequestStatus
from app.schemas.common import UtcDateTime


class DeviceChangeIn(BaseModel):
    identifier: str
    password: str
    device_id: str = Field(min_length=4, max_length=64)
    reason: str = Field(min_length=3, max_length=255)


class DeviceRequestOut(BaseModel):
    id: int
    student_user_id: str
    student_id: str | None
    student_name: str
    reason: str
    status: DeviceRequestStatus
    created_at: UtcDateTime
    resolved_at: UtcDateTime | None
