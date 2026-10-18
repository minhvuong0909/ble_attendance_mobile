from fastapi import APIRouter, Depends, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import hash_password, require_roles
from app.core.validators import normalize_id
from app.models import ClassRoom, Course, Enrollment, LectureSession, User, UserRole
from app.schemas.admin import (
    AssignTeacherIn,
    ClassCreate,
    ClassUpdate,
    CourseIn,
    CourseOut,
    CourseUpdate,
    TeacherCreate,
)
from app.schemas.auth import UserOut
from app.schemas.classes import ClassOut
from app.services.academic import class_to_out, new_join_code

router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(require_roles(UserRole.admin))],
)


def _get_course(db: Session, course_id: str) -> Course:
    course = db.get(Course, course_id)
    if course is None:
        raise ApiError(404, "course_not_found", "Không tìm thấy môn học")
    return course


def _get_class(db: Session, class_id: str) -> ClassRoom:
    cls = db.get(ClassRoom, class_id)
    if cls is None:
        raise ApiError(404, "class_not_found", "Không tìm thấy lớp")
    return cls


def _get_teacher(db: Session, teacher_user_id: str) -> User:
    teacher = db.get(User, teacher_user_id)
    if teacher is None or teacher.role != UserRole.teacher:
        raise ApiError(404, "teacher_not_found", "Không tìm thấy giảng viên")
    return teacher


@router.post("/courses", response_model=CourseOut, status_code=201)
def create_course(payload: CourseIn, db: Session = Depends(get_db)) -> Course:
    code = payload.code.strip().upper()
    if db.scalar(select(Course.id).where(Course.code == code)) is not None:
        raise ApiError(409, "course_exists", "Mã môn học đã tồn tại")
    course = Course(code=code, name=payload.name.strip(), credits=payload.credits)
    db.add(course)
    db.commit()
    db.refresh(course)
    return course


@router.get("/courses", response_model=list[CourseOut])
def list_courses(db: Session = Depends(get_db)) -> list[Course]:
    return list(db.scalars(select(Course).order_by(Course.code)))


@router.patch("/courses/{course_id}", response_model=CourseOut)
def update_course(course_id: str, payload: CourseUpdate, db: Session = Depends(get_db)) -> Course:
    course = _get_course(db, course_id)
    if payload.name is not None:
        course.name = payload.name.strip()
    if payload.credits is not None:
        course.credits = payload.credits
    db.commit()
    db.refresh(course)
    return course


@router.delete("/courses/{course_id}", status_code=204)
def delete_course(course_id: str, db: Session = Depends(get_db)) -> Response:
    course = _get_course(db, course_id)
    if db.scalar(select(ClassRoom.id).where(ClassRoom.course_id == course.id)) is not None:
        raise ApiError(409, "course_has_classes", "Môn học đang có lớp, không thể xóa")
    db.delete(course)
    db.commit()
    return Response(status_code=204)


@router.post("/classes", response_model=ClassOut, status_code=201)
def create_class(payload: ClassCreate, db: Session = Depends(get_db)) -> ClassOut:
    _get_course(db, payload.course_id)
    if payload.teacher_user_id is not None:
        _get_teacher(db, payload.teacher_user_id)
    class_code = payload.class_code.strip().upper()
    duplicate = db.scalar(
        select(ClassRoom.id).where(
            ClassRoom.course_id == payload.course_id,
            ClassRoom.class_code == class_code,
            ClassRoom.semester == payload.semester,
        )
    )
    if duplicate is not None:
        raise ApiError(409, "class_exists", "Lớp này đã tồn tại trong học kỳ")
    cls = ClassRoom(
        course_id=payload.course_id,
        class_code=class_code,
        semester=payload.semester.strip(),
        teacher_user_id=payload.teacher_user_id,
        join_code=new_join_code(db),
        max_absence_percent=payload.max_absence_percent,
        rssi_threshold=payload.rssi_threshold,
    )
    db.add(cls)
    db.commit()
    db.refresh(cls)
    return class_to_out(db, cls)


@router.get("/classes", response_model=list[ClassOut])
def list_classes(db: Session = Depends(get_db)) -> list[ClassOut]:
    stmt = (
        select(ClassRoom)
        .join(Course, ClassRoom.course_id == Course.id)
        .order_by(Course.code, ClassRoom.class_code)
    )
    return [class_to_out(db, cls) for cls in db.scalars(stmt)]


@router.patch("/classes/{class_id}", response_model=ClassOut)
def update_class(class_id: str, payload: ClassUpdate, db: Session = Depends(get_db)) -> ClassOut:
    cls = _get_class(db, class_id)
    if payload.class_code is not None:
        cls.class_code = payload.class_code.strip().upper()
    if payload.semester is not None:
        cls.semester = payload.semester.strip()
    if payload.max_absence_percent is not None:
        cls.max_absence_percent = payload.max_absence_percent
    if payload.rssi_threshold is not None:
        cls.rssi_threshold = payload.rssi_threshold
    db.commit()
    db.refresh(cls)
    return class_to_out(db, cls)


@router.delete("/classes/{class_id}", status_code=204)
def delete_class(class_id: str, db: Session = Depends(get_db)) -> Response:
    cls = _get_class(db, class_id)
    has_sessions = db.scalar(select(LectureSession.id).where(LectureSession.class_id == cls.id))
    has_students = db.scalar(select(Enrollment.id).where(Enrollment.class_id == cls.id))
    if has_sessions is not None or has_students is not None:
        raise ApiError(409, "class_not_empty", "Lớp đã có sinh viên hoặc buổi học, không thể xóa")
    db.delete(cls)
    db.commit()
    return Response(status_code=204)


@router.post("/classes/{class_id}/assign-teacher", response_model=ClassOut)
def assign_teacher(class_id: str, payload: AssignTeacherIn, db: Session = Depends(get_db)) -> ClassOut:
    cls = _get_class(db, class_id)
    teacher = _get_teacher(db, payload.teacher_user_id)
    active = db.scalar(
        select(LectureSession.id).where(
            LectureSession.class_id == cls.id, LectureSession.is_active.is_(True)
        )
    )
    if active is not None and cls.teacher_user_id != teacher.id:
        raise ApiError(409, "class_has_active_session", "Lớp đang có buổi học, chưa thể đổi giảng viên")
    cls.teacher_user_id = teacher.id
    db.commit()
    db.refresh(cls)
    return class_to_out(db, cls)


@router.post("/teachers", response_model=UserOut, status_code=201)
def create_teacher(payload: TeacherCreate, db: Session = Depends(get_db)) -> User:
    teacher_id = normalize_id(payload.teacher_id)
    if db.scalar(select(User.id).where(User.teacher_id == teacher_id)) is not None:
        raise ApiError(409, "teacher_exists", "Mã giảng viên đã tồn tại")
    teacher = User(
        full_name=payload.full_name.strip(),
        role=UserRole.teacher,
        teacher_id=teacher_id,
        password_hash=hash_password(teacher_id),
        must_change_password=True,
    )
    db.add(teacher)
    db.commit()
    db.refresh(teacher)
    return teacher


@router.get("/teachers", response_model=list[UserOut])
def list_teachers(db: Session = Depends(get_db)) -> list[User]:
    return list(db.scalars(select(User).where(User.role == UserRole.teacher).order_by(User.teacher_id)))


@router.post("/users/{user_id}/reset-password")
def reset_password(user_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    user = db.get(User, user_id)
    if user is None:
        raise ApiError(404, "user_not_found", "Không tìm thấy người dùng")
    user.password_hash = hash_password(user.login_id)
    user.must_change_password = True
    db.commit()
    return {"message": "ok"}
