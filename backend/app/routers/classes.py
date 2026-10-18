from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import get_current_user, require_roles
from app.models import ClassRoom, Course, Enrollment, User, UserRole
from app.schemas.classes import ClassOut, JoinClassIn, StudentOut
from app.services.academic import class_to_out
from app.services.access import get_class_or_404, is_enrolled, require_class_access

router = APIRouter(prefix="/classes", tags=["classes"])


@router.get("/mine", response_model=list[ClassOut])
def my_classes(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[ClassOut]:
    stmt = select(ClassRoom).join(Course, ClassRoom.course_id == Course.id)
    if user.role == UserRole.teacher:
        stmt = stmt.where(ClassRoom.teacher_user_id == user.id)
    elif user.role == UserRole.student:
        stmt = stmt.join(Enrollment, Enrollment.class_id == ClassRoom.id).where(
            Enrollment.student_user_id == user.id
        )
    stmt = stmt.order_by(Course.code, ClassRoom.class_code)
    show_code = user.role != UserRole.student
    return [class_to_out(db, cls, include_join_code=show_code) for cls in db.scalars(stmt)]


@router.post("/join", response_model=ClassOut)
def join_class(
    payload: JoinClassIn,
    db: Session = Depends(get_db),
    student: User = Depends(require_roles(UserRole.student)),
) -> ClassOut:
    code = payload.join_code.strip().upper()
    cls = db.scalar(select(ClassRoom).where(ClassRoom.join_code == code))
    if cls is None:
        raise ApiError(404, "invalid_join_code", "Mã lớp không hợp lệ")
    if is_enrolled(db, cls.id, student.id):
        raise ApiError(409, "already_enrolled", "Bạn đã ở trong lớp này")
    db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="join_code"))
    db.commit()
    return class_to_out(db, cls, include_join_code=False)


@router.get("/{class_id}", response_model=ClassOut)
def class_detail(
    class_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> ClassOut:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    return class_to_out(db, cls, include_join_code=user.role != UserRole.student)


@router.get("/{class_id}/students", response_model=list[StudentOut])
def class_students(
    class_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(UserRole.teacher, UserRole.admin)),
) -> list[User]:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    stmt = (
        select(User)
        .join(Enrollment, Enrollment.student_user_id == User.id)
        .where(Enrollment.class_id == cls.id)
        .order_by(User.student_id)
    )
    return list(db.scalars(stmt))
