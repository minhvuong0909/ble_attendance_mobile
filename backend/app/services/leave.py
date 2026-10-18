from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.clock import local_date
from app.models import Attendance, AttendanceStatus, ClassRoom, LeaveRequest, LectureSession, User
from app.schemas.leave import LeaveOut


def leave_to_out(db: Session, leave: LeaveRequest) -> LeaveOut:
    student = db.get(User, leave.student_user_id)
    cls = db.get(ClassRoom, leave.class_id)
    return LeaveOut(
        id=leave.id,
        student_user_id=student.id,
        student_id=student.student_id,
        student_name=student.full_name,
        class_id=cls.id,
        course_code=cls.course.code,
        class_code=cls.class_code,
        date=leave.date,
        reason=leave.reason,
        status=leave.status,
        created_at=leave.created_at,
        reviewed_at=leave.reviewed_at,
        review_note=leave.review_note,
    )


def apply_leave_to_settled_sessions(db: Session, leave: LeaveRequest) -> int:
    """Đơn được duyệt: các buổi đã kết thúc cùng ngày địa phương mà SV đang vắng (chưa bị GV chỉnh tay) thành có phép."""
    sessions = db.scalars(
        select(LectureSession).where(
            LectureSession.class_id == leave.class_id, LectureSession.is_active.is_(False)
        )
    )
    session_ids = [s.id for s in sessions if local_date(s.starts_at) == leave.date]
    if not session_ids:
        return 0
    rows = db.scalars(
        select(Attendance).where(
            Attendance.session_id.in_(session_ids),
            Attendance.student_user_id == leave.student_user_id,
            Attendance.status == AttendanceStatus.absent,
            Attendance.overridden_by.is_(None),
        )
    ).all()
    for row in rows:
        row.status = AttendanceStatus.excused
    return len(rows)
