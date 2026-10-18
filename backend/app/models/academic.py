from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.clock import utcnow
from app.core.database import Base
from app.core.ids import new_id
from app.models.user import User


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    credits: Mapped[int | None] = mapped_column(Integer, nullable=True)


class ClassRoom(Base):
    __tablename__ = "classes"
    __table_args__ = (
        UniqueConstraint("course_id", "class_code", "semester", name="uq_class_course_code_semester"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    course_id: Mapped[str] = mapped_column(String(36), ForeignKey("courses.id"), nullable=False)
    class_code: Mapped[str] = mapped_column(String(32), nullable=False)
    semester: Mapped[str] = mapped_column(String(32), nullable=False)
    teacher_user_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("users.id"), nullable=True)
    join_code: Mapped[str] = mapped_column(String(12), unique=True, nullable=False)
    max_absence_percent: Mapped[int] = mapped_column(Integer, default=20, nullable=False)
    rssi_threshold: Mapped[int] = mapped_column(Integer, default=-75, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    course: Mapped[Course] = relationship()
    teacher: Mapped[User | None] = relationship(foreign_keys=[teacher_user_id])


class Enrollment(Base):
    __tablename__ = "enrollments"
    __table_args__ = (UniqueConstraint("class_id", "student_user_id", name="uq_enrollment_class_student"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    class_id: Mapped[str] = mapped_column(String(36), ForeignKey("classes.id"), nullable=False)
    student_user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    source: Mapped[str] = mapped_column(String(16), default="import", nullable=False)
