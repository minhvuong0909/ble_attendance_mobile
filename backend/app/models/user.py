from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.clock import utcnow
from app.core.database import Base
from app.core.ids import new_id


class UserRole(str, Enum):
    admin = "admin"
    teacher = "teacher"
    student = "student"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    student_id: Mapped[str | None] = mapped_column(String(16), unique=True, nullable=True)
    # Dùng chung cho mã giảng viên và mã admin.
    teacher_id: Mapped[str | None] = mapped_column(String(16), unique=True, nullable=True)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    role: Mapped[UserRole] = mapped_column(SqlEnum(UserRole, native_enum=False, length=16), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    must_change_password: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    @property
    def login_id(self) -> str:
        return self.student_id or self.teacher_id or ""
