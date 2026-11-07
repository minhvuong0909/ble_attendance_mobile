from fastapi import APIRouter, Depends
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.clock import utcnow
from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import create_access_token, get_current_user, hash_password, verify_password
from app.core.validators import is_valid_student_id, normalize_id
from app.models import DeviceChangeRequest, DeviceRequestStatus, User, UserRole
from app.schemas.device import DeviceChangeIn, DeviceRequestOut
from app.services.accounts import login_id_taken
from app.services.devices import check_device, request_to_out
from app.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut, status_code=201)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> User:
    identifier = normalize_id(payload.identifier)
    if not is_valid_student_id(identifier):
        raise ApiError(422, "invalid_student_id", "Mã sinh viên phải có dạng 25CE099 hoặc D26CE045")
    if login_id_taken(db, identifier):
        raise ApiError(409, "student_exists", "Mã sinh viên đã tồn tại")
    user = User(
        full_name=payload.full_name.strip(),
        role=UserRole.student,
        student_id=identifier,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    identifier = normalize_id(payload.identifier)
    user = db.scalar(select(User).where(or_(User.student_id == identifier, User.teacher_id == identifier)))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise ApiError(401, "invalid_credentials", "Sai mã đăng nhập hoặc mật khẩu")
    if user.role == UserRole.student:
        check_device(db, user, payload.device_id)
    return TokenResponse(
        access_token=create_access_token(user.id),
        must_change_password=user.must_change_password,
    )


@router.post("/device-change-requests", response_model=DeviceRequestOut, status_code=201)
def create_device_change_request(payload: DeviceChangeIn, db: Session = Depends(get_db)) -> dict:
    """Sinh viên gửi đơn đổi máy từ máy mới. Chưa đăng nhập được nên xác thực bằng mật khẩu."""
    identifier = normalize_id(payload.identifier)
    user = db.scalar(select(User).where(User.student_id == identifier))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise ApiError(401, "invalid_credentials", "Sai mã đăng nhập hoặc mật khẩu")
    if user.device_id is None:
        raise ApiError(409, "device_not_bound", "Tài khoản chưa gắn thiết bị, cứ đăng nhập bình thường")
    if user.device_id == payload.device_id:
        raise ApiError(409, "same_device", "Đây đã là thiết bị của tài khoản")
    row = db.scalar(
        select(DeviceChangeRequest).where(
            DeviceChangeRequest.student_user_id == user.id,
            DeviceChangeRequest.status == DeviceRequestStatus.pending,
        )
    )
    if row is None:
        row = DeviceChangeRequest(student_user_id=user.id, new_device_id=payload.device_id, reason=payload.reason)
        db.add(row)
    else:
        row.new_device_id = payload.device_id
        row.reason = payload.reason
        row.created_at = utcnow()
    db.commit()
    db.refresh(row)
    return request_to_out(row, user)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)) -> User:
    return user


@router.post("/change-password")
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict[str, str]:
    if not verify_password(payload.old_password, user.password_hash):
        raise ApiError(400, "invalid_password", "Mật khẩu hiện tại không đúng")
    user.password_hash = hash_password(payload.new_password)
    user.must_change_password = False
    db.commit()
    return {"message": "ok"}
