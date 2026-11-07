from datetime import datetime, timedelta, timezone

from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.errors import ApiError
from app.models import User, UserRole

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


def hash_password(raw_password: str) -> str:
    return pwd_context.hash(raw_password)


def verify_password(raw_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(raw_password, hashed_password)


def create_access_token(subject: str) -> str:
    expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_exp_minutes)
    return jwt.encode({"sub": subject, "exp": expiry}, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def get_current_user_allow_pending(
    token: str | None = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> User:
    bearer = {"WWW-Authenticate": "Bearer"}
    if not token:
        raise ApiError(401, "not_authenticated", "Bạn chưa đăng nhập", headers=bearer)
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError as exc:
        raise ApiError(401, "invalid_token", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn", headers=bearer) from exc
    user = db.get(User, payload.get("sub"))
    if user is None:
        raise ApiError(401, "invalid_token", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn", headers=bearer)
    return user


def get_current_user(user: User = Depends(get_current_user_allow_pending)) -> User:
    """Người dùng đã đăng nhập và không còn bị buộc đổi mật khẩu (chặn ở backend, không chỉ ở client)."""
    if user.must_change_password:
        raise ApiError(403, "password_change_required", "Bạn cần đổi mật khẩu trước khi tiếp tục")
    return user


def require_roles(*roles: UserRole):
    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise ApiError(403, "forbidden", "Bạn không có quyền thực hiện thao tác này")
        return user

    return checker
