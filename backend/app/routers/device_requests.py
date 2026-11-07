from typing import Literal

from fastapi import APIRouter, Depends
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.core.clock import utcnow
from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import require_roles
from app.models import DeviceChangeRequest, DeviceRequestStatus, User, UserRole
from app.schemas.device import DeviceRequestOut
from app.services.devices import request_to_out
from app.services.notifier import notify

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/device-requests", response_model=list[DeviceRequestOut])
def list_device_requests(
    status: Literal["pending", "approved", "rejected"] | None = None,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_roles(UserRole.admin)),
) -> list[dict]:
    stmt = select(DeviceChangeRequest, User).join(User, User.id == DeviceChangeRequest.student_user_id)
    if status is not None:
        stmt = stmt.where(DeviceChangeRequest.status == DeviceRequestStatus(status))
    rows = db.execute(stmt.order_by(desc(DeviceChangeRequest.id))).all()
    return [request_to_out(row, student) for row, student in rows]


def _resolve(db: Session, request_id: int, admin: User, approve: bool) -> dict:
    row = db.get(DeviceChangeRequest, request_id)
    if row is None:
        raise ApiError(404, "request_not_found", "Không tìm thấy đơn đổi thiết bị")
    if row.status != DeviceRequestStatus.pending:
        raise ApiError(409, "request_resolved", "Đơn này đã được xử lý")
    student = db.get(User, row.student_user_id)
    row.status = DeviceRequestStatus.approved if approve else DeviceRequestStatus.rejected
    row.resolved_by = admin.id
    row.resolved_at = utcnow()
    if approve:
        student.device_id = row.new_device_id
        notify(db, student.id, "device_change_approved", "Đơn đổi thiết bị được duyệt",
               "Bạn có thể đăng nhập bằng thiết bị mới.", ref_id=str(row.id))
    else:
        notify(db, student.id, "device_change_rejected", "Đơn đổi thiết bị bị từ chối",
               "Tài khoản vẫn gắn với thiết bị cũ. Liên hệ admin nếu cần.", ref_id=str(row.id))
    db.commit()
    db.refresh(row)
    return request_to_out(row, student)


@router.post("/device-requests/{request_id}/approve", response_model=DeviceRequestOut)
def approve_device_request(
    request_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles(UserRole.admin)),
) -> dict:
    return _resolve(db, request_id, admin, approve=True)


@router.post("/device-requests/{request_id}/reject", response_model=DeviceRequestOut)
def reject_device_request(
    request_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_roles(UserRole.admin)),
) -> dict:
    return _resolve(db, request_id, admin, approve=False)
