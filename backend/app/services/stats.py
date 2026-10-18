from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Attendance, AttendanceStatus, ClassRoom, LectureSession


@dataclass(frozen=True)
class ClassStats:
    total: int
    present: int
    absent: int
    excused: int
    attendance_percent: float
    absent_percent: float
    warning: bool


def class_stats(db: Session, cls: ClassRoom, student_user_id: str) -> ClassStats:
    """Chuyên cần của một SV trong lớp, chỉ tính buổi đã kết thúc mà SV có bản ghi."""
    statuses = list(
        db.scalars(
            select(Attendance.status)
            .join(LectureSession, LectureSession.id == Attendance.session_id)
            .where(
                LectureSession.class_id == cls.id,
                LectureSession.is_active.is_(False),
                Attendance.student_user_id == student_user_id,
            )
        )
    )
    return stats_from_statuses(statuses, cls.max_absence_percent)


def stats_from_statuses(statuses: list[AttendanceStatus], max_absence_percent: int) -> ClassStats:
    total = len(statuses)
    if total == 0:
        return ClassStats(0, 0, 0, 0, 100.0, 0.0, False)

    present = statuses.count(AttendanceStatus.present)
    absent = statuses.count(AttendanceStatus.absent)
    excused = statuses.count(AttendanceStatus.excused)
    return ClassStats(
        total=total,
        present=present,
        absent=absent,
        excused=excused,
        attendance_percent=round((present + excused) / total * 100, 1),
        absent_percent=round(absent / total * 100, 1),
        # So sánh bằng số nguyên để không bị lệch do làm tròn: absent/total > max/100.
        warning=absent * 100 > max_absence_percent * total,
    )


def late_minutes(starts_at: datetime, first_seen_at: datetime | None) -> int | None:
    if first_seen_at is None:
        return None
    return max(0, int((first_seen_at - starts_at).total_seconds() // 60))
