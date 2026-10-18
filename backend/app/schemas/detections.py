from datetime import datetime

from pydantic import BaseModel, Field


class DetectionItem(BaseModel):
    session_id: str
    student_identifier: str
    bucket: int
    tag: str = Field(min_length=8, max_length=8)
    rssi: int = Field(ge=-127, le=0)
    observed_at: datetime


class DetectionBatchIn(BaseModel):
    detections: list[DetectionItem] = Field(max_length=500)


class DetectionBatchOut(BaseModel):
    recorded: int
    rejected: int
