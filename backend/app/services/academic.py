import secrets

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import ClassRoom, Enrollment
from app.schemas.classes import ClassOut


def new_join_code(db: Session) -> str:
    while True:
        code = secrets.token_hex(3).upper()
        if db.scalar(select(ClassRoom.id).where(ClassRoom.join_code == code)) is None:
            return code


def class_to_out(db: Session, cls: ClassRoom, include_join_code: bool = True) -> ClassOut:
    count = db.scalar(select(func.count(Enrollment.id)).where(Enrollment.class_id == cls.id)) or 0
    return ClassOut(
        id=cls.id,
        course_id=cls.course_id,
        course_code=cls.course.code,
        course_name=cls.course.name,
        class_code=cls.class_code,
        semester=cls.semester,
        teacher_user_id=cls.teacher_user_id,
        teacher_name=cls.teacher.full_name if cls.teacher else None,
        join_code=cls.join_code if include_join_code else None,
        max_absence_percent=cls.max_absence_percent,
        rssi_threshold=cls.rssi_threshold,
        student_count=count,
    )
