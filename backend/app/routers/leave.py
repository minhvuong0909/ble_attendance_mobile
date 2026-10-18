from fastapi import APIRouter, Depends
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import require_roles
from app.models import ClassRoom, LeaveRequest, LeaveStatus, User, UserRole
from app.schemas.leave import LeaveCreate, LeaveOut, LeaveReview
from app.services.access import get_class_or_404, is_enrolled, require_class_access
from app.services.leave import leave_to_out, review_leave_request
from app.services.notifier import notify

router = APIRouter(tags=["leave"])

STAFF = require_roles(UserRole.teacher, UserRole.admin)


@router.post("/leave-requests", response_model=LeaveOut, status_code=201)
def create_leave(
    payload: LeaveCreate,
    db: Session = Depends(get_db),
    student: User = Depends(require_roles(UserRole.student)),
) -> LeaveOut:
    cls = get_class_or_404(db, payload.class_id)
    if not is_enrolled(db, cls.id, student.id):
        raise ApiError(404, "class_not_found", "Không tìm thấy lớp")
    open_request = db.scalar(
        select(LeaveRequest.id).where(
            LeaveRequest.student_user_id == student.id,
            LeaveRequest.class_id == cls.id,
            LeaveRequest.date == payload.date,
            LeaveRequest.status.in_([LeaveStatus.pending, LeaveStatus.approved]),
        )
    )
    if open_request is not None:
        raise ApiError(409, "leave_exists", "Bạn đã có đơn xin phép cho ngày này")

    leave = LeaveRequest(
        student_user_id=student.id,
        class_id=cls.id,
        date=payload.date,
        reason=payload.reason.strip(),
    )
    db.add(leave)
    db.flush()
    if cls.teacher_user_id:
        notify(
            db,
            cls.teacher_user_id,
            "leave_submitted",
            "Đơn xin phép mới",
            f"{student.full_name} ({student.student_id}) xin phép vắng ngày "
            f"{payload.date:%d/%m/%Y} môn {cls.course.code}.",
            ref_id=str(leave.id),
        )
    db.commit()
    return leave_to_out(db, leave)


@router.get("/leave-requests/mine", response_model=list[LeaveOut])
def my_leave_requests(
    class_id: str | None = None,
    db: Session = Depends(get_db),
    student: User = Depends(require_roles(UserRole.student)),
) -> list[LeaveOut]:
    stmt = select(LeaveRequest).where(LeaveRequest.student_user_id == student.id)
    if class_id is not None:
        stmt = stmt.where(LeaveRequest.class_id == class_id)
    stmt = stmt.order_by(desc(LeaveRequest.created_at), desc(LeaveRequest.id))
    return [leave_to_out(db, leave) for leave in db.scalars(stmt)]


@router.get("/classes/{class_id}/leave-requests", response_model=list[LeaveOut])
def class_leave_requests(
    class_id: str,
    status: LeaveStatus | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(STAFF),
) -> list[LeaveOut]:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    stmt = select(LeaveRequest).where(LeaveRequest.class_id == cls.id)
    if status is not None:
        stmt = stmt.where(LeaveRequest.status == status)
    stmt = stmt.order_by(desc(LeaveRequest.created_at), desc(LeaveRequest.id))
    return [leave_to_out(db, leave) for leave in db.scalars(stmt)]


@router.post("/leave-requests/{leave_id}/review", response_model=LeaveOut)
def review_leave(
    leave_id: int,
    payload: LeaveReview,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> LeaveOut:
    leave = db.get(LeaveRequest, leave_id)
    cls = db.get(ClassRoom, leave.class_id) if leave else None
    if leave is None or cls is None or cls.teacher_user_id != teacher.id:
        raise ApiError(404, "leave_not_found", "Không tìm thấy đơn xin phép")
    if not review_leave_request(db, leave, teacher, payload.decision, payload.note):
        db.rollback()
        raise ApiError(409, "already_reviewed", "Đơn này đã được xử lý")
    db.commit()
    return leave_to_out(db, leave)
