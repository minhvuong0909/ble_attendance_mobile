from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models import User


def login_id_taken(db: Session, identifier: str) -> bool:
    """Mã đăng nhập là duy nhất trên cả cột student_id lẫn teacher_id."""
    stmt = select(User.id).where(or_(User.student_id == identifier, User.teacher_id == identifier))
    return db.scalar(stmt) is not None
