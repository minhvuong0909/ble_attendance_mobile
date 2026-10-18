from fastapi import APIRouter, Depends
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import require_roles
from app.models import Attendance, ClassRoom, Course, Enrollment, LectureSession, User, UserRole
from app.schemas.stats import AttendanceHistoryItem, ClassStatsOut
from app.services.access import get_class_or_404, is_enrolled
from app.services.stats import class_stats, late_minutes

router = APIRouter(prefix="/me", tags=["me"])


@router.get("/attendance", response_model=list[AttendanceHistoryItem])
def my_attendance(
    class_id: str,
    db: Session = Depends(get_db),
    student: User = Depends(require_roles(UserRole.student)),
) -> list[AttendanceHistoryItem]:
    cls = get_class_or_404(db, class_id)
    if not is_enrolled(db, cls.id, student.id):
        raise ApiError(404, "class_not_found", "Không tìm thấy lớp")
    rows = db.execute(
        select(Attendance, LectureSession)
        .join(LectureSession, LectureSession.id == Attendance.session_id)
        .where(
            LectureSession.class_id == cls.id,
            LectureSession.is_active.is_(False),
            Attendance.student_user_id == student.id,
        )
        .order_by(desc(LectureSession.starts_at))
    ).all()
    return [
        AttendanceHistoryItem(
            session_id=session.id,
            starts_at=session.starts_at,
            ends_at=session.ends_at,
            status=attendance.status,
            presence_ratio=attendance.presence_ratio,
            first_seen_at=attendance.first_seen_at,
            late_minutes=late_minutes(session.starts_at, attendance.first_seen_at),
        )
        for attendance, session in rows
    ]


@router.get("/attendance/stats", response_model=list[ClassStatsOut])
def my_attendance_stats(
    db: Session = Depends(get_db),
    student: User = Depends(require_roles(UserRole.student)),
) -> list[ClassStatsOut]:
    classes = db.scalars(
        select(ClassRoom)
        .join(Course, ClassRoom.course_id == Course.id)
        .join(Enrollment, Enrollment.class_id == ClassRoom.id)
        .where(Enrollment.student_user_id == student.id)
        .order_by(Course.code, ClassRoom.class_code)
    )
    result: list[ClassStatsOut] = []
    for cls in classes:
        stats = class_stats(db, cls, student.id)
        result.append(
            ClassStatsOut(
                class_id=cls.id,
                course_code=cls.course.code,
                course_name=cls.course.name,
                class_code=cls.class_code,
                semester=cls.semester,
                total_sessions=stats.total,
                present=stats.present,
                absent=stats.absent,
                excused=stats.excused,
                attendance_percent=stats.attendance_percent,
                absent_percent=stats.absent_percent,
                max_absence_percent=cls.max_absence_percent,
                warning=stats.warning,
            )
        )
    return result
