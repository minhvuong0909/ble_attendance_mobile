from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AttendanceStatus(str, Enum):
    present = "present"
    absent = "absent"
    excused = "excused"


class Attendance(Base):
    __tablename__ = "attendance"
    __table_args__ = (UniqueConstraint("session_id", "student_user_id", name="uq_attendance_session_student"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(String(36), ForeignKey("sessions.id"), nullable=False)
    student_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    presence_ratio: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    status: Mapped[AttendanceStatus] = mapped_column(
        SqlEnum(AttendanceStatus, native_enum=False, length=16),
        default=AttendanceStatus.absent,
        nullable=False,
    )
    finalized: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    finalized_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    first_seen_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    overridden_by: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)
    overridden_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    override_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
