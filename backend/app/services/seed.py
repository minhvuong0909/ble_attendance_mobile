from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models import ClassRoom, Course, Enrollment, User, UserRole
from app.services.academic import new_join_code

DEMO_PASSWORD = "123456"
SEMESTER = "FA26"

TEACHERS = [
    ("GV1", "Giảng viên Demo"),
    ("GV2", "Giảng viên Demo 2"),
    ("GV3", "Giảng viên Demo 3"),
]
STUDENTS = [
    ("SV1", "Sinh viên Một"),
    ("SV2", "Sinh viên Hai"),
    ("SV3", "Sinh viên Ba"),
]
# (mã môn, tên môn, tín chỉ)
COURSES = [
    ("PRM393", "Lập trình di động", 3),
    ("PRN232", "Phát triển ứng dụng web với .NET", 3),
    ("MLN131", "Chủ nghĩa xã hội khoa học", 2),
    ("EXE201", "Khởi nghiệp trải nghiệm 2", 3),
]
# (mã môn, mã lớp, mã giảng viên, mã sinh viên được ghi danh sẵn)
CLASSES = [
    ("PRM393", "SE1901", "GV1", ["SV1", "SV2", "SV3"]),
    ("PRN232", "SE1918", "GV2", []),
    ("MLN131", "Half2_EL1902", "GV3", []),
    ("EXE201", "SE1919", "GV2", []),
]


def _ensure_user(db: Session, role: UserRole, ident: str, name: str) -> User:
    column = User.student_id if role == UserRole.student else User.teacher_id
    user = db.scalar(select(User).where(column == ident))
    if user is None:
        ids = {"student_id": ident} if role == UserRole.student else {"teacher_id": ident}
        user = User(full_name=name, role=role, password_hash=hash_password(DEMO_PASSWORD), **ids)
        db.add(user)
        db.flush()
    return user


def _ensure_course(db: Session, code: str, name: str, credits: int) -> Course:
    course = db.scalar(select(Course).where(Course.code == code))
    if course is None:
        course = Course(code=code, name=name, credits=credits)
        db.add(course)
        db.flush()
    return course


def seed(db: Session) -> None:
    """Tạo dữ liệu demo (chạy lại không tạo trùng). Sinh viên được xếp lớp sẵn như danh sách ghi danh."""
    _ensure_user(db, UserRole.admin, "ADMIN", "Quản trị viên")
    teachers = {ident: _ensure_user(db, UserRole.teacher, ident, name) for ident, name in TEACHERS}
    students = {ident: _ensure_user(db, UserRole.student, ident, name) for ident, name in STUDENTS}
    courses = {code: _ensure_course(db, code, name, credits) for code, name, credits in COURSES}

    for course_code, class_code, teacher_id, enrolled in CLASSES:
        course = courses[course_code]
        cls = db.scalar(
            select(ClassRoom).where(
                ClassRoom.course_id == course.id,
                ClassRoom.class_code == class_code,
                ClassRoom.semester == SEMESTER,
            )
        )
        if cls is None:
            cls = ClassRoom(
                course_id=course.id,
                class_code=class_code,
                semester=SEMESTER,
                teacher_user_id=teachers[teacher_id].id,
                join_code=new_join_code(db),
            )
            db.add(cls)
            db.flush()

        for ident in enrolled:
            student = students[ident]
            exists = db.scalar(
                select(Enrollment.id).where(
                    Enrollment.class_id == cls.id, Enrollment.student_user_id == student.id
                )
            )
            if exists is None:
                db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="import"))

    db.commit()
