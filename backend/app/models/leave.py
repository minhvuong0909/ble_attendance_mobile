from datetime import date, datetime
from enum import Enum

from sqlalchemy import Date, DateTime, Enum as SqlEnum, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.clock import utcnow
from app.core.database import Base


class LeaveStatus(str, Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class LeaveRequest(Base):
    __tablename__ = "leave_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    student_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    class_id: Mapped[str] = mapped_column(String(36), ForeignKey("classes.id"), nullable=False)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    status: Mapped[LeaveStatus] = mapped_column(
        SqlEnum(LeaveStatus, native_enum=False, length=16),
        default=LeaveStatus.pending,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    reviewed_by: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    review_note: Mapped[str | None] = mapped_column(String(255), nullable=True)
