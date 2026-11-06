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
from app.services.notifier import notify, notify_many
from app.services.presence import PRESENT_THRESHOLD, Sample, first_seen_at, presence_ratio
from app.services.stats import stats_from_statuses

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


def session_samples(db: Session, session_id: str) -> dict[str, list[Sample]]:
    """Toàn bộ mẫu của buổi học, gom theo sinh viên bằng một truy vấn."""
    grouped: dict[str, list[Sample]] = {}
    rows = db.execute(
        select(Detection.student_user_id, Detection.detected_at, Detection.rssi).where(
            Detection.session_id == session_id
        )
    )
    for student_user_id, moment, rssi in rows:
        grouped.setdefault(student_user_id, []).append((moment, rssi))
    return grouped


def approved_leave_user_ids(db: Session, class_id: str, session: LectureSession) -> set[str]:
    """Sinh viên có đơn đã duyệt cho ngày (địa phương) của buổi học."""
    return set(
        db.scalars(
            select(LeaveRequest.student_user_id).where(
                LeaveRequest.class_id == class_id,
                LeaveRequest.status == LeaveStatus.approved,
                LeaveRequest.date == local_date(session.starts_at),
            )
        )
    )


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
    all_samples = session_samples(db, session.id)
    excused_ids = approved_leave_user_ids(db, cls.id, session)
    rows = {
        row.student_user_id: row
        for row in db.scalars(select(Attendance).where(Attendance.session_id == session.id))
    }
    for student in enrolled_students(db, cls.id):
        samples = all_samples.get(student.id, [])
        row = rows.get(student.id)
        if row is None:
            row = Attendance(session_id=session.id, student_user_id=student.id)
            db.add(row)
        row.presence_ratio = presence_ratio(session.starts_at, end, samples, cls.rssi_threshold)
        row.first_seen_at = first_seen_at(samples, session.starts_at, end, cls.rssi_threshold)
        if row.overridden_by is None:
            row.status = resolve_status(row.presence_ratio, row.finalized, student.id in excused_ids)
    db.flush()


def notify_absence_warnings(db: Session, session: LectureSession) -> None:
    """Cảnh báo SV vắng buổi này và đã vượt mức vắng tối đa của lớp."""
    cls = db.get(ClassRoom, session.class_id)
    absent_ids = list(
        db.scalars(
            select(Attendance.student_user_id).where(
                Attendance.session_id == session.id, Attendance.status == AttendanceStatus.absent
            )
        )
    )
    if not absent_ids:
        return
    history: dict[str, list[AttendanceStatus]] = {}
    rows = db.execute(
        select(Attendance.student_user_id, Attendance.status)
        .join(LectureSession, LectureSession.id == Attendance.session_id)
        .where(
            LectureSession.class_id == cls.id,
            LectureSession.is_active.is_(False),
            Attendance.student_user_id.in_(absent_ids),
        )
    )
    for student_user_id, status in rows:
        history.setdefault(student_user_id, []).append(status)
    for student_user_id in absent_ids:
        stats = stats_from_statuses(history.get(student_user_id, []), cls.max_absence_percent)
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


def open_finalization(db: Session, session: LectureSession) -> bool:
    """Mở chốt điểm danh và báo cho SV trong lớp. Trả False nếu đã mở rồi (kể cả bởi request khác).

    UPDATE có điều kiện để hai request đồng thời không gửi thông báo hai lần. Người gọi chịu trách nhiệm commit.
    """
    result = db.execute(
        update(LectureSession)
        .where(
            LectureSession.id == session.id,
            LectureSession.is_active.is_(True),
            LectureSession.finalization_open.is_(False),
        )
        .values(finalization_open=True)
        .execution_options(synchronize_session=False)
    )
    db.refresh(session)
    if result.rowcount != 1:
        return False
    cls = db.get(ClassRoom, session.class_id)
    notify_many(
        db,
        [student.id for student in enrolled_students(db, cls.id)],
        "finalization_open",
        "Mở chốt điểm danh",
        f"Giảng viên đã mở chốt điểm danh môn {cls.course.code}. Hãy xác nhận ngay.",
        ref_id=session.id,
    )
    return True


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
    all_samples = session_samples(db, session.id)
    excused_ids = approved_leave_user_ids(db, cls.id, session)
    records: list[AttendanceRecordOut] = []
    for student in enrolled_students(db, cls.id):
        samples = all_samples.get(student.id, [])
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
            status = resolve_status(ratio, bool(row and row.finalized), student.id in excused_ids)

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
