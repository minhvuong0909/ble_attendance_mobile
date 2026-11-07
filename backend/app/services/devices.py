from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import DeviceChangeRequest, User


def check_device(db: Session, user: User, device_id: str | None) -> None:
    """Mỗi sinh viên gắn với đúng một máy, gắn ở lần đăng nhập đầu. Đổi máy phải qua đơn do admin duyệt."""
    if not device_id:
        raise ApiError(422, "device_required", "Thiếu mã thiết bị, hãy dùng ứng dụng điểm danh")
    if user.device_id is None:
        user.device_id = device_id
        db.commit()
        return
    if user.device_id != device_id:
        raise ApiError(
            403,
            "device_mismatch",
            "Tài khoản đã gắn với một thiết bị khác. Hãy gửi đơn đổi thiết bị cho admin",
        )


def request_to_out(row: DeviceChangeRequest, student: User) -> dict:
    return {
        "id": row.id,
        "student_user_id": student.id,
        "student_id": student.student_id,
        "student_name": student.full_name,
        "reason": row.reason,
        "status": row.status,
        "created_at": row.created_at,
        "resolved_at": row.resolved_at,
    }
