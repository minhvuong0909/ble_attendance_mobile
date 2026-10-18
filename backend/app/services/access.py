from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import ClassRoom, Enrollment, LectureSession, User, UserRole


def get_class_or_404(db: Session, class_id: str) -> ClassRoom:
    cls = db.get(ClassRoom, class_id)
    if cls is None:
        raise ApiError(404, "class_not_found", "Không tìm thấy lớp")
    return cls


def is_enrolled(db: Session, class_id: str, student_user_id: str) -> bool:
    return (
        db.scalar(
            select(Enrollment.id).where(
                Enrollment.class_id == class_id, Enrollment.student_user_id == student_user_id
            )
        )
        is not None
    )


def require_class_access(db: Session, user: User, cls: ClassRoom) -> None:
    if user.role == UserRole.admin:
        return
    if user.role == UserRole.teacher and cls.teacher_user_id == user.id:
        return
    if user.role == UserRole.student and is_enrolled(db, cls.id, user.id):
        return
    raise ApiError(404, "class_not_found", "Không tìm thấy lớp")


def get_session_or_404(db: Session, session_id: str) -> LectureSession:
    session = db.get(LectureSession, session_id)
    if session is None:
        raise ApiError(404, "session_not_found", "Không tìm thấy buổi học")
    return session


def require_session_class_teacher(db: Session, user: User, session: LectureSession) -> None:
    """Xem và chỉnh điểm danh theo giảng viên hiện tại của lớp, không theo người đã mở buổi."""
    cls = db.get(ClassRoom, session.class_id)
    if cls is None or cls.teacher_user_id != user.id:
        raise ApiError(404, "session_not_found", "Không tìm thấy buổi học")


def require_session_teacher(user: User, session: LectureSession) -> None:
    if session.teacher_user_id != user.id:
        raise ApiError(404, "session_not_found", "Không tìm thấy buổi học")
