from pydantic import BaseModel, ConfigDict, Field


class ClassOut(BaseModel):
    id: str
    course_id: str
    course_code: str
    course_name: str
    class_code: str
    semester: str
    teacher_user_id: str | None
    teacher_name: str | None
    join_code: str | None
    max_absence_percent: int
    rssi_threshold: int
    student_count: int


class StudentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    student_id: str | None
    full_name: str


class JoinClassIn(BaseModel):
    join_code: str = Field(min_length=4, max_length=12)
