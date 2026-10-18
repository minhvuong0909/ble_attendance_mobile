import secrets

from fastapi import APIRouter, Depends
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.core.clock import utcnow
from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import get_current_user, require_roles
from app.models import ClassRoom, Enrollment, LectureSession, User, UserRole
from app.schemas.sessions import SessionOut
from app.services.access import (
    get_class_or_404,
    get_session_or_404,
    require_class_access,
    require_session_teacher,
)
from app.services.attendance import close_session, enrolled_students
from app.services.beacon import student_secret
from app.services.lecture import session_to_out
from app.services.notifier import notify_many

router = APIRouter(tags=["sessions"])


@router.post("/classes/{class_id}/sessions", response_model=SessionOut, status_code=201)
def start_session(
    class_id: str,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> SessionOut:
    cls = get_class_or_404(db, class_id)
    if cls.teacher_user_id != teacher.id:
        raise ApiError(403, "forbidden", "Bạn không được phân công lớp này")
    active = db.scalar(
        select(LectureSession.id).where(
            LectureSession.teacher_user_id == teacher.id, LectureSession.is_active.is_(True)
        )
    )
    if active is not None:
        raise ApiError(409, "session_already_active", "Bạn đang có một buổi học chưa kết thúc")
    session = LectureSession(
        class_id=cls.id, teacher_user_id=teacher.id, token=secrets.token_hex(8), starts_at=utcnow()
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session_to_out(db, session)


@router.get("/classes/{class_id}/sessions", response_model=list[SessionOut])
def class_sessions(
    class_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> list[SessionOut]:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    stmt = select(LectureSession).where(LectureSession.class_id == cls.id).order_by(desc(LectureSession.starts_at))
    return [session_to_out(db, s) for s in db.scalars(stmt)]


@router.post("/sessions/{session_id}/end", response_model=SessionOut)
def end_session(
    session_id: str,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> SessionOut:
    session = get_session_or_404(db, session_id)
    require_session_teacher(teacher, session)
    close_session(db, session)
    db.commit()
    return session_to_out(db, session)


@router.post("/sessions/{session_id}/open-finalization", response_model=SessionOut)
def open_finalization(
    session_id: str,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> SessionOut:
    session = get_session_or_404(db, session_id)
    require_session_teacher(teacher, session)
    if not session.is_active:
        raise ApiError(409, "session_ended", "Buổi học đã kết thúc")
    if not session.finalization_open:
        session.finalization_open = True
        cls = db.get(ClassRoom, session.class_id)
        notify_many(
            db,
            [student.id for student in enrolled_students(db, cls.id)],
            "finalization_open",
            "Mở chốt điểm danh",
            f"Giảng viên đã mở chốt điểm danh môn {cls.course.code}. Hãy xác nhận ngay.",
            ref_id=session.id,
        )
    db.commit()
    return session_to_out(db, session)


@router.get("/sessions/active", response_model=SessionOut)
def active_session(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(UserRole.teacher, UserRole.student)),
) -> SessionOut:
    stmt = select(LectureSession).where(LectureSession.is_active.is_(True))
    if user.role == UserRole.teacher:
        stmt = stmt.where(LectureSession.teacher_user_id == user.id)
    else:
        stmt = stmt.join(Enrollment, Enrollment.class_id == LectureSession.class_id).where(
            Enrollment.student_user_id == user.id
        )
    session = db.scalar(stmt.order_by(desc(LectureSession.starts_at)))
    if session is None:
        raise ApiError(404, "no_active_session", "Hiện không có buổi học nào đang diễn ra")
    secret = student_secret(session.id, user.student_id) if user.role == UserRole.student else None
    return session_to_out(db, session, beacon_secret=secret)
