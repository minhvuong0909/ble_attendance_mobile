from datetime import datetime

from pydantic import BaseModel, Field

from app.models import AttendanceStatus


class FinalizeIn(BaseModel):
    session_id: str


class FinalizeOut(BaseModel):
    session_id: str
    finalized: bool
    finalized_at: datetime | None


class OverrideIn(BaseModel):
    student_user_id: str
    status: AttendanceStatus
    reason: str = Field(min_length=3, max_length=255)


class OverrideOut(BaseModel):
    student_user_id: str
    status: AttendanceStatus
    overridden_by: str
    overridden_at: datetime
    override_reason: str


class AttendanceRecordOut(BaseModel):
    student_user_id: str
    student_id: str | None
    student_name: str
    detection_count: int
    presence_ratio: float
    status: AttendanceStatus
    finalized: bool
    first_seen_at: datetime | None
    overridden: bool
    override_reason: str | None


class SessionAttendanceOut(BaseModel):
    session_id: str
    class_id: str
    total_students: int
    present_students: int
    records: list[AttendanceRecordOut]
