import datetime as dt
from typing import Literal

from pydantic import BaseModel, Field

from app.models import LeaveStatus
from app.schemas.common import UtcDateTime


class LeaveCreate(BaseModel):
    class_id: str
    date: dt.date
    reason: str = Field(min_length=3, max_length=500)


class LeaveReview(BaseModel):
    decision: Literal["approved", "rejected"]
    note: str | None = Field(default=None, max_length=255)


class LeaveOut(BaseModel):
    id: int
    student_user_id: str
    student_id: str | None
    student_name: str
    class_id: str
    course_code: str
    class_code: str
    date: dt.date
    reason: str
    status: LeaveStatus
    created_at: UtcDateTime
    reviewed_at: UtcDateTime | None
    review_note: str | None
