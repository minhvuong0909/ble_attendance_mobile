from pydantic import BaseModel

from app.schemas.common import UtcDateTime


class SessionOut(BaseModel):
    id: str
    class_id: str
    class_code: str
    course_code: str
    course_name: str
    teacher_user_id: str
    beacon_code: str
    starts_at: UtcDateTime
    ends_at: UtcDateTime | None
    is_active: bool
    finalization_open: bool
    beacon_secret: str | None = None
