from sqlalchemy.orm import Session

from app.models import ClassRoom, LectureSession
from app.schemas.sessions import SessionOut


def session_to_out(db: Session, session: LectureSession, beacon_secret: str | None = None) -> SessionOut:
    cls = db.get(ClassRoom, session.class_id)
    return SessionOut(
        id=session.id,
        class_id=session.class_id,
        class_code=cls.class_code,
        course_code=cls.course.code,
        course_name=cls.course.name,
        teacher_user_id=session.teacher_user_id,
        beacon_code=session.token[:8],
        starts_at=session.starts_at,
        ends_at=session.ends_at,
        is_active=session.is_active,
        finalization_open=session.finalization_open,
        beacon_secret=beacon_secret,
    )
