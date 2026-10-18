from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.clock import utcnow
from app.core.database import Base
from app.core.ids import new_id


class LectureSession(Base):
    __tablename__ = "sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    class_id: Mapped[str] = mapped_column(String(36), ForeignKey("classes.id"), nullable=False)
    teacher_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    token: Mapped[str] = mapped_column(String(64), nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    finalization_open: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)


class Detection(Base):
    __tablename__ = "detections"
    __table_args__ = (Index("ix_detections_lookup", "session_id", "student_user_id", "detected_at"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(String(36), ForeignKey("sessions.id"), nullable=False)
    student_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    rssi: Mapped[int] = mapped_column(Integer, nullable=False)
    detected_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
