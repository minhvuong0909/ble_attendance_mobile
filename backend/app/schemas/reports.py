from pydantic import BaseModel

from app.models import AttendanceStatus
from app.schemas.common import UtcDateTime


class ReportSession(BaseModel):
    id: str
    starts_at: UtcDateTime


class ReportStudent(BaseModel):
    student_user_id: str
    student_id: str | None
    student_name: str
    cells: list[AttendanceStatus | None]
    present: int
    absent: int
    excused: int
    attendance_percent: float
    absent_percent: float
    warning: bool


class ClassReportOut(BaseModel):
    class_id: str
    course_code: str
    course_name: str
    class_code: str
    semester: str
    sessions: list[ReportSession]
    students: list[ReportStudent]
    average_attendance_percent: float
