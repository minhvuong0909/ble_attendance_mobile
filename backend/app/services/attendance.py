from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.clock import local_date, utcnow
from app.models import (
    Attendance,
    AttendanceStatus,
    ClassRoom,
    Detection,
    Enrollment,
    LeaveRequest,
    LeaveStatus,
    LectureSession,
    User,
)
from app.schemas.attendance import AttendanceRecordOut
from app.services.notifier import notify
from app.services.presence import PRESENT_THRESHOLD, Sample, first_seen_at, presence_ratio
from app.services.stats import class_stats

RECENT_DETECTION_SECONDS = 90


def resolve_status(ratio: float, finalized: bool, excused: bool) -> AttendanceStatus:
    if ratio >= PRESENT_THRESHOLD and finalized:
        return AttendanceStatus.present
    if excused:
        return AttendanceStatus.excused
    return AttendanceStatus.absent


def enrolled_students(db: Session, class_id: str) -> list[User]:
    stmt = (
        select(User)
        .join(Enrollment, Enrollment.student_user_id == User.id)
        .where(Enrollment.class_id == class_id)
        .order_by(User.student_id)
    )
    return list(db.scalars(stmt))


def student_samples(db: Session, session_id: str, student_user_id: str) -> list[Sample]:
    rows = db.execute(
        select(Detection.detected_at, Detection.rssi).where(
            Detection.session_id == session_id, Detection.student_user_id == student_user_id
        )
    ).all()
    return [(moment, rssi) for moment, rssi in rows]


def has_approved_leave(db: Session, class_id: str, student_user_id: str, session: LectureSession) -> bool:
    found = db.scalar(
        select(LeaveRequest.id).where(
            LeaveRequest.class_id == class_id,
            LeaveRequest.student_user_id == student_user_id,
            LeaveRequest.status == LeaveStatus.approved,
            LeaveRequest.date == local_date(session.starts_at),
        )
    )
    return found is not None


def get_or_create_row(db: Session, session_id: str, student_user_id: str) -> Attendance:
    row = db.scalar(
        select(Attendance).where(
            Attendance.session_id == session_id, Attendance.student_user_id == student_user_id
        )
    )
    if row is None:
        row = Attendance(session_id=session_id, student_user_id=student_user_id)
        db.add(row)
        db.flush()
    return row


def finalize_session(db: Session, session: LectureSession) -> None:
    """Tính kết quả cuối buổi cho toàn bộ sinh viên của lớp. Người gọi chịu trách nhiệm commit."""
    cls = db.get(ClassRoom, session.class_id)
    end = session.ends_at or utcnow()
    for student in enrolled_students(db, cls.id):
        samples = student_samples(db, session.id, student.id)
        row = get_or_create_row(db, session.id, student.id)
        row.presence_ratio = presence_ratio(session.starts_at, end, samples, cls.rssi_threshold)
        row.first_seen_at = first_seen_at(samples, session.starts_at, end, cls.rssi_threshold)
        if row.overridden_by is None:
            excused = has_approved_leave(db, cls.id, student.id, session)
            row.status = resolve_status(row.presence_ratio, row.finalized, excused)
    db.flush()


def notify_absence_warnings(db: Session, session: LectureSession) -> None:
    """Cảnh báo SV vắng buổi này và đã vượt mức vắng tối đa của lớp."""
    cls = db.get(ClassRoom, session.class_id)
    absent_ids = db.scalars(
        select(Attendance.student_user_id).where(
            Attendance.session_id == session.id, Attendance.status == AttendanceStatus.absent
        )
    )
    for student_user_id in absent_ids:
        stats = class_stats(db, cls, student_user_id)
        if stats.warning:
            notify(
                db,
                student_user_id,
                "absence_warning",
                "Cảnh báo vắng học",
                f"Bạn đã vắng {stats.absent_percent}% số buổi môn {cls.course.code} ({cls.class_code}), "
                f"vượt mức cho phép {cls.max_absence_percent}%.",
                ref_id=cls.id,
            )


def close_session(db: Session, session: LectureSession) -> bool:
    """Đóng buổi học và chốt kết quả cả lớp. Trả False nếu một request khác đã đóng trước.

    Dùng UPDATE có điều kiện để hai request kết thúc chạy chồng nhau không tính lại hai lần.
    Người gọi chịu trách nhiệm commit.
    """
    result = db.execute(
        update(LectureSession)
        .where(LectureSession.id == session.id, LectureSession.is_active.is_(True))
        .values(is_active=False, finalization_open=False, ends_at=utcnow())
        .execution_options(synchronize_session=False)
    )
    db.refresh(session)
    if result.rowcount != 1:
        return False
    finalize_session(db, session)
    notify_absence_warnings(db, session)
    return True


def build_records(db: Session, session: LectureSession) -> list[AttendanceRecordOut]:
    cls = db.get(ClassRoom, session.class_id)
    end = session.ends_at or utcnow()
    rows = {
        row.student_user_id: row
        for row in db.scalars(select(Attendance).where(Attendance.session_id == session.id))
    }
    records: list[AttendanceRecordOut] = []
    for student in enrolled_students(db, cls.id):
        samples = student_samples(db, session.id, student.id)
        row = rows.get(student.id)
        settled = row is not None and not session.is_active

        if settled:
            ratio, first_seen = row.presence_ratio, row.first_seen_at
        else:
            ratio = presence_ratio(session.starts_at, end, samples, cls.rssi_threshold)
            first_seen = first_seen_at(samples, session.starts_at, end, cls.rssi_threshold)

        if row is not None and (row.overridden_by is not None or settled):
            status = row.status
        else:
            excused = has_approved_leave(db, cls.id, student.id, session)
            status = resolve_status(ratio, bool(row and row.finalized), excused)

        records.append(
            AttendanceRecordOut(
                student_user_id=student.id,
                student_id=student.student_id,
                student_name=student.full_name,
                detection_count=len(samples),
                presence_ratio=ratio,
                status=status,
                finalized=bool(row and row.finalized),
                first_seen_at=first_seen,
                overridden=bool(row and row.overridden_by is not None),
                override_reason=row.override_reason if row else None,
            )
        )
    return records
