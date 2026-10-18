from pydantic import BaseModel, ConfigDict, Field


class CourseIn(BaseModel):
    code: str = Field(min_length=2, max_length=32)
    name: str = Field(min_length=2, max_length=120)
    credits: int | None = Field(default=None, ge=0, le=30)


class CourseUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    credits: int | None = Field(default=None, ge=0, le=30)


class CourseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: str
    name: str
    credits: int | None


class ClassCreate(BaseModel):
    course_id: str
    class_code: str = Field(min_length=1, max_length=32)
    semester: str = Field(min_length=2, max_length=32)
    teacher_user_id: str | None = None
    max_absence_percent: int = Field(default=20, ge=0, le=100)
    rssi_threshold: int = Field(default=-75, ge=-100, le=-30)


class ClassUpdate(BaseModel):
    class_code: str | None = Field(default=None, min_length=1, max_length=32)
    semester: str | None = Field(default=None, min_length=2, max_length=32)
    max_absence_percent: int | None = Field(default=None, ge=0, le=100)
    rssi_threshold: int | None = Field(default=None, ge=-100, le=-30)


class AssignTeacherIn(BaseModel):
    teacher_user_id: str


class TeacherCreate(BaseModel):
    teacher_id: str = Field(min_length=3, max_length=16)
    full_name: str = Field(min_length=2, max_length=120)
