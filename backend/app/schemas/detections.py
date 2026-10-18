from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class DetectionItem(BaseModel):
    session_id: str
    student_identifier: str
    bucket: int
    tag: str = Field(min_length=8, max_length=8)
    rssi: int
    observed_at: datetime

    @field_validator("observed_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None:
            raise ValueError("observed_at phải kèm múi giờ, ví dụ 2026-10-18T03:00:00Z")
        return value


class DetectionBatchIn(BaseModel):
    detections: list[DetectionItem] = Field(max_length=500)


class DetectionBatchOut(BaseModel):
    recorded: int
    rejected: int
