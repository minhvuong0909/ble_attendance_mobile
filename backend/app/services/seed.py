from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models import ClassRoom, Course, Enrollment, User, UserRole
from app.services.academic import new_join_code

DEMO_PASSWORD = "Pass@123"


def _ensure_user(db: Session, role: UserRole, ident: str, name: str) -> User:
    column = User.student_id if role == UserRole.student else User.teacher_id
    user = db.scalar(select(User).where(column == ident))
    if user is None:
        ids = {"student_id": ident} if role == UserRole.student else {"teacher_id": ident}
        user = User(full_name=name, role=role, password_hash=hash_password(DEMO_PASSWORD), **ids)
        db.add(user)
        db.flush()
    return user


def seed(db: Session) -> dict[str, str]:
    _ensure_user(db, UserRole.admin, "A001", "Quản trị viên")
    teacher = _ensure_user(db, UserRole.teacher, "T001", "Giảng viên Demo")
    students = [
        _ensure_user(db, UserRole.student, "25CE099", "Sinh viên Một"),
        _ensure_user(db, UserRole.student, "25CE100", "Sinh viên Hai"),
        _ensure_user(db, UserRole.student, "D26CE045", "Sinh viên Ba"),
    ]

    course = db.scalar(select(Course).where(Course.code == "PRM393"))
    if course is None:
        course = Course(code="PRM393", name="Lập trình di động", credits=3)
        db.add(course)
        db.flush()

    cls = db.scalar(
        select(ClassRoom).where(
            ClassRoom.course_id == course.id,
            ClassRoom.class_code == "SE1901",
            ClassRoom.semester == "FA26",
        )
    )
    if cls is None:
        cls = ClassRoom(
            course_id=course.id,
            class_code="SE1901",
            semester="FA26",
            teacher_user_id=teacher.id,
            join_code=new_join_code(db),
        )
        db.add(cls)
        db.flush()

    for student in students:
        exists = db.scalar(
            select(Enrollment.id).where(
                Enrollment.class_id == cls.id, Enrollment.student_user_id == student.id
            )
        )
        if exists is None:
            db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="import"))

    db.commit()
    return {"join_code": cls.join_code}
