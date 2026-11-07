import secrets

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.models import ClassRoom, Enrollment
from app.schemas.classes import ClassOut


def new_join_code(db: Session) -> str:
    while True:
        code = secrets.token_hex(3).upper()
        if db.scalar(select(ClassRoom.id).where(ClassRoom.join_code == code)) is None:
            return code


def with_class_relations(stmt):
    """Nạp sẵn môn học và giảng viên để danh sách lớp không phát sinh truy vấn cho từng dòng."""
    return stmt.options(selectinload(ClassRoom.course), selectinload(ClassRoom.teacher))


def classes_to_out(db: Session, classes: list[ClassRoom], include_join_code: bool = True) -> list[ClassOut]:
    """Danh sách lớp với số sinh viên lấy bằng một truy vấn gộp."""
    ids = [cls.id for cls in classes]
    counts: dict[str, int] = {}
    if ids:
        counts = dict(
            db.execute(
                select(Enrollment.class_id, func.count(Enrollment.id))
                .where(Enrollment.class_id.in_(ids))
                .group_by(Enrollment.class_id)
            ).all()
        )
    return [class_to_out(db, cls, include_join_code, counts.get(cls.id, 0)) for cls in classes]


def class_to_out(
    db: Session, cls: ClassRoom, include_join_code: bool = True, student_count: int | None = None
) -> ClassOut:
    count = student_count
    if count is None:
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
