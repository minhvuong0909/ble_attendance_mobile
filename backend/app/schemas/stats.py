from pydantic import BaseModel

from app.models import AttendanceStatus
from app.schemas.common import UtcDateTime


class AttendanceHistoryItem(BaseModel):
    session_id: str
    starts_at: UtcDateTime
    ends_at: UtcDateTime | None
    status: AttendanceStatus
    presence_ratio: float
    first_seen_at: UtcDateTime | None
    late_minutes: int | None


class ClassStatsOut(BaseModel):
    class_id: str
    course_code: str
    course_name: str
    class_code: str
    semester: str
    total_sessions: int
    present: int
    absent: int
    excused: int
    attendance_percent: float
    absent_percent: float
    max_absence_percent: int
    warning: bool
