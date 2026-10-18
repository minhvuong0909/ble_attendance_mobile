from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.clock import utcnow
from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import require_roles
from app.models import AttendanceStatus, ClassRoom, Detection, User, UserRole
from app.schemas.attendance import (
    FinalizeIn,
    FinalizeOut,
    OverrideIn,
    OverrideOut,
    SessionAttendanceOut,
)
from app.services.access import get_session_or_404, is_enrolled, require_session_teacher
from app.services.attendance import (
    RECENT_DETECTION_SECONDS,
    build_records,
    get_or_create_row,
)

router = APIRouter(tags=["attendance"])


@router.post("/attendance/finalize", response_model=FinalizeOut)
def finalize_attendance(
    payload: FinalizeIn,
    db: Session = Depends(get_db),
    student: User = Depends(require_roles(UserRole.student)),
) -> FinalizeOut:
    session = get_session_or_404(db, payload.session_id)
    if not is_enrolled(db, session.class_id, student.id):
        raise ApiError(404, "session_not_found", "Không tìm thấy buổi học")
    if not session.is_active:
        raise ApiError(409, "session_ended", "Buổi học đã kết thúc")
    if not session.finalization_open:
        raise ApiError(409, "finalization_not_open", "Giảng viên chưa mở chốt điểm danh")

    cls = db.get(ClassRoom, session.class_id)
    cutoff = utcnow() - timedelta(seconds=RECENT_DETECTION_SECONDS)
    recent = db.scalar(
        select(func.count(Detection.id)).where(
            Detection.session_id == session.id,
            Detection.student_user_id == student.id,
            Detection.detected_at >= cutoff,
            Detection.rssi > cls.rssi_threshold,
        )
    )
    if not recent:
        raise ApiError(409, "not_in_range", "Chưa phát hiện bạn trong lớp, hãy lại gần giảng viên")

    row = get_or_create_row(db, session.id, student.id)
    row.finalized = True
    row.finalized_at = utcnow()
    db.commit()
    return FinalizeOut(session_id=session.id, finalized=True, finalized_at=row.finalized_at)


@router.get("/sessions/{session_id}/attendance", response_model=SessionAttendanceOut)
def session_attendance(
    session_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(UserRole.teacher, UserRole.admin)),
) -> SessionAttendanceOut:
    session = get_session_or_404(db, session_id)
    if user.role == UserRole.teacher:
        require_session_teacher(user, session)
    records = build_records(db, session)
    present = sum(1 for record in records if record.status == AttendanceStatus.present)
    return SessionAttendanceOut(
        session_id=session.id,
        class_id=session.class_id,
        total_students=len(records),
        present_students=present,
        records=records,
    )


@router.post("/sessions/{session_id}/attendance/override", response_model=OverrideOut)
def override_attendance(
    session_id: str,
    payload: OverrideIn,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> OverrideOut:
    session = get_session_or_404(db, session_id)
    require_session_teacher(teacher, session)
    if not is_enrolled(db, session.class_id, payload.student_user_id):
        raise ApiError(404, "student_not_in_class", "Sinh viên không thuộc lớp này")

    row = get_or_create_row(db, session.id, payload.student_user_id)
    row.status = payload.status
    row.overridden_by = teacher.id
    row.overridden_at = utcnow()
    row.override_reason = payload.reason.strip()
    db.commit()
    return OverrideOut(
        student_user_id=row.student_user_id,
        status=row.status,
        overridden_by=teacher.id,
        overridden_at=row.overridden_at,
        override_reason=row.override_reason,
    )
