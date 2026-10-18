from fastapi import APIRouter, Depends
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import create_access_token, get_current_user, hash_password, verify_password
from app.core.validators import is_valid_student_id, normalize_id
from app.models import User, UserRole
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
    if db.scalar(select(User.id).where(User.student_id == identifier)) is not None:
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
    return TokenResponse(
        access_token=create_access_token(user.id),
        must_change_password=user.must_change_password,
    )


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
