# Backend Core Implementation Plan (Plan 1/5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng lại backend FastAPI theo cấu trúc mới (core/models/routers/services, Alembic, pytest) và hoàn thành lõi điểm danh: 3 vai trò, học vụ (môn/lớp/GV), buổi học theo lớp, xác minh beacon HMAC, công thức presence mới, chốt điểm danh, override.

**Architecture:** Router mỏng gọi service; logic thuần (presence, beacon) tách riêng để unit test; mọi lỗi nghiệp vụ trả `{detail, code}` qua `ApiError`. Test dùng SQLite in-memory; thời gian lưu dạng naive UTC. Schema quản lý bằng Alembic (một migration baseline gồm cả các bảng của Plan 2 như `leave_requests`, `notifications`).

**Tech Stack:** Python 3.12, FastAPI 0.115, SQLAlchemy 2.0, Alembic, Pydantic 2, python-jose, passlib (pbkdf2_sha256), pytest, httpx.

**Spec:** `docs/superpowers/specs/2026-10-18-ble-attendance-expansion-design.md` (mục 2, 3, 4, 5, 6)

**Các plan còn lại (sẽ viết sau khi Plan 1 xong):** Plan 2 backend phần 2 (import, báo cáo, thống kê SV, xin phép, thông báo) · Plan 3 Flutter nền tảng (cấu trúc, Riverpod, go_router, auth, khung 3 role) · Plan 4 Flutter tính năng (Admin, GV, SV) · Plan 5 BLE có tag, hoàn thiện, release APK.

## Global Constraints

- Python 3.12; chạy lệnh trong `backend/` với venv `backend/.venv`.
- Chỉ Android là client; không làm gì cho iOS.
- Thời gian lưu **naive UTC** qua `app.core.clock.utcnow()`; không dùng `datetime.utcnow()`.
- Cửa sổ điểm danh **30 giây**; ngưỡng có mặt `PRESENT_THRESHOLD = 0.6`; `classes.rssi_threshold` mặc định **-75**; `classes.max_absence_percent` mặc định **20**.
- Cửa sổ hợp lệ khi **trung vị RSSI > rssi_threshold** (so sánh nghiêm ngặt); server không tin cờ `proximity_ok` từ client.
- Tag beacon: `hex(HMAC_SHA256(student_secret, str(bucket)))[:8]`, `bucket = floor(epoch_seconds / 30)`; `student_secret = HMAC_SHA256(BEACON_SERVER_KEY, "{session_id}:{student_id}")` dạng hex; chấp nhận bucket lệch **±1** so với `observed_at`; `observed_at` không lệch quá **10 phút** so với giờ server.
- Chốt điểm danh cần detection hợp lệ trong **90 giây** gần nhất (`RECENT_DETECTION_SECONDS = 90`).
- Tài khoản tạo bởi admin có mật khẩu tạm bằng chính mã định danh (đã viết hoa) và `must_change_password = true`.
- Mã định danh luôn được chuẩn hóa `strip().upper()`.
- Mã SV khớp `^(?:\d{2}[A-Z]{2,3}\d{3}|D\d{2}[A-Z]{2,3}\d{3})$`.
- Lỗi nghiệp vụ: `{"detail": "<tiếng Việt>", "code": "<snake_case>"}`.
- Vai trò: `admin`, `teacher`, `student`. Mã GV và mã admin dùng chung cột `users.teacher_id`.
- JWT HS256, hết hạn mặc định 480 phút. Hash mật khẩu `pbkdf2_sha256`.
- Giờ địa phương cho "ngày buổi học" (đối chiếu đơn xin phép) = UTC + `local_utc_offset_hours` (mặc định 7).
- Nhánh làm việc: `feature/backend-core` (không code trên `main`).

## Review Focus

1. Buổi học bắt đầu 06:30 giờ địa phương (23:30 UTC hôm trước) phải khớp đơn xin phép của đúng ngày địa phương → test ở Task 9.
2. Batch detection có `observed_at` mang offset (`+07:00`) phải được đổi về UTC trước khi so sánh → test ở Task 8.
3. Kết thúc buổi gọi hai lần (retry mạng) không tính lại, không đổi `ends_at` → test ở Task 9.
4. Mã nhập chữ thường hoặc có khoảng trắng (`" 25ce099 "`) vẫn đăng nhập/đăng ký/ghi nhận đúng → test ở Task 3 và 8.
5. Payload đăng ký có `"role": "admin"` hoặc `"teacher"` vẫn tạo ra sinh viên → test ở Task 3.

## File Structure

```
backend/
├── requirements.txt              (sửa: thêm alembic)
├── requirements-dev.txt          (mới)
├── pytest.ini                    (mới)
├── alembic.ini, alembic/         (mới)
├── app/
│   ├── main.py                   (viết lại: app + error handler + include router)
│   ├── core/{config,database,clock,errors,ids,security,validators}.py
│   ├── models/{user,academic,lecture,attendance,leave,notification}.py + __init__.py
│   ├── schemas/{auth,admin,classes,sessions,detections,attendance}.py
│   ├── routers/{auth,admin,classes,sessions,detections,attendance}.py
│   └── services/{presence,beacon,access,academic,lecture,attendance,seed}.py
├── scripts/seed_demo.py          (viết lại, gọi services/seed.py)
└── tests/                        (conftest + một file test cho mỗi module)
```
Các file cũ `app/{auth,config,database,models,schemas,services}.py` bị xóa ở Task 1.

---

### Task 1: Hạ tầng test và gói `core`

**Files:**
- Create: `backend/requirements-dev.txt`, `backend/pytest.ini`
- Create: `backend/app/core/__init__.py`, `config.py`, `database.py`, `clock.py`, `errors.py`, `ids.py`
- Modify: `backend/requirements.txt`, `backend/app/main.py`
- Delete: `backend/app/{auth,config,database,models,schemas,services}.py`
- Create: `backend/tests/__init__.py`, `conftest.py`, `test_clock.py`, `test_errors.py`, `test_health.py`

**Interfaces:**
- Produces: `app.core.config.settings` (có `beacon_server_key`, `local_utc_offset_hours`), `app.core.database.{Base,get_db,engine}`, `app.core.clock.{utcnow,to_naive_utc,local_date}`, `app.core.errors.{ApiError,register_error_handlers}`, `app.core.ids.new_id`, fixtures `db`, `client`.

- [ ] **Step 1: Tạo nhánh và môi trường**

```bash
cd /home/kiet/code/PRM/ble_attendance_mobile
git switch -c feature/backend-core
cd backend
python3 -m venv .venv
echo ".venv/" >> ../.gitignore
```

- [ ] **Step 2: Cập nhật requirements**

Thêm dòng `alembic==1.14.0` vào cuối `backend/requirements.txt`. Tạo `backend/requirements-dev.txt`:

```text
-r requirements.txt
pytest==8.3.4
httpx==0.28.1
```

```bash
.venv/bin/pip install -r requirements-dev.txt
```
Expected: cài thành công, không lỗi.

- [ ] **Step 3: Tạo `pytest.ini`**

```ini
[pytest]
testpaths = tests
pythonpath = .
filterwarnings =
    ignore::DeprecationWarning
```

- [ ] **Step 4: Viết test thất bại cho `clock` và `errors` và `health`**

`backend/tests/__init__.py` để trống.

`backend/tests/test_clock.py`:

```python
from datetime import date, datetime, timedelta, timezone

from app.core.clock import local_date, to_naive_utc, utcnow


def test_utcnow_is_naive():
    assert utcnow().tzinfo is None


def test_to_naive_utc_converts_offset_to_utc():
    aware = datetime(2026, 10, 18, 10, 0, tzinfo=timezone(timedelta(hours=7)))
    assert to_naive_utc(aware) == datetime(2026, 10, 18, 3, 0)


def test_to_naive_utc_keeps_naive_value():
    value = datetime(2026, 10, 18, 3, 0)
    assert to_naive_utc(value) == value


def test_local_date_uses_utc_plus_7():
    assert local_date(datetime(2026, 10, 17, 23, 30)) == date(2026, 10, 18)
    assert local_date(datetime(2026, 10, 18, 3, 0)) == date(2026, 10, 18)
```

`backend/tests/test_errors.py`:

```python
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.errors import ApiError, register_error_handlers


def test_api_error_is_rendered_as_detail_and_code():
    app = FastAPI()
    register_error_handlers(app)

    @app.get("/boom")
    def boom():
        raise ApiError(409, "something_wrong", "Có lỗi")

    response = TestClient(app).get("/boom")
    assert response.status_code == 409
    assert response.json() == {"detail": "Có lỗi", "code": "something_wrong"}


def test_api_error_forwards_headers():
    app = FastAPI()
    register_error_handlers(app)

    @app.get("/auth")
    def auth():
        raise ApiError(401, "invalid_token", "x", headers={"WWW-Authenticate": "Bearer"})

    response = TestClient(app).get("/auth")
    assert response.headers["www-authenticate"] == "Bearer"
```

`backend/tests/test_health.py`:

```python
def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

`backend/tests/conftest.py`:

```python
import os

os.environ["DATABASE_URL_OVERRIDE"] = "sqlite://"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["BEACON_SERVER_KEY"] = "key"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine, autoflush=False, autocommit=False)()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture()
def client(db):
    def override():
        yield db

    app.dependency_overrides[get_db] = override
    yield TestClient(app)
    app.dependency_overrides.clear()
```

- [ ] **Step 5: Chạy test để thấy thất bại**

Run: `cd backend && .venv/bin/pytest -q`
Expected: lỗi `ModuleNotFoundError: No module named 'app.core'`.

- [ ] **Step 6: Xóa file cũ và viết gói `core`**

```bash
git rm app/auth.py app/config.py app/database.py app/models.py app/schemas.py app/services.py
mkdir -p app/core
touch app/core/__init__.py
```

`backend/app/core/config.py`:

```python
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "BLE Attendance API"
    app_env: str = "dev"
    debug: bool = True

    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "ble_attendance"
    db_user: str = "postgres"
    db_password: str = "postgres"
    database_url_override: str | None = None

    jwt_secret: str = "change-this-in-production"
    jwt_algorithm: str = "HS256"
    jwt_exp_minutes: int = 60 * 8

    beacon_server_key: str = "change-this-beacon-key"
    local_utc_offset_hours: int = 7

    model_config = SettingsConfigDict(
        env_file=str(Path(__file__).resolve().parents[2] / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def database_url(self) -> str:
        if self.database_url_override:
            return self.database_url_override
        return (
            f"postgresql+psycopg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


settings = Settings()
```

`backend/app/core/database.py`:

```python
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings


class Base(DeclarativeBase):
    pass


engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

`backend/app/core/clock.py`:

```python
from datetime import date, datetime, timedelta, timezone

from app.core.config import settings


def utcnow() -> datetime:
    """Giờ UTC dạng naive, thống nhất cho toàn bộ cột DateTime."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def to_naive_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def local_date(value: datetime) -> date:
    """Ngày theo giờ địa phương của một thời điểm UTC naive."""
    return (value + timedelta(hours=settings.local_utc_offset_hours)).date()
```

`backend/app/core/errors.py`:

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(
        self,
        status_code: int,
        code: str,
        detail: str,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.code = code
        self.detail = detail
        self.headers = headers


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def handle_api_error(_: Request, exc: ApiError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail, "code": exc.code},
            headers=exc.headers,
        )
```

`backend/app/core/ids.py`:

```python
from uuid import uuid4


def new_id() -> str:
    return str(uuid4())
```

`backend/app/main.py` (thay toàn bộ nội dung):

```python
from fastapi import FastAPI

from app.core.config import settings
from app.core.errors import register_error_handlers

app = FastAPI(title=settings.app_name)
register_error_handlers(app)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}
```

- [ ] **Step 7: Chạy test để thấy đạt**

Run: `.venv/bin/pytest -q`
Expected: `7 passed`.

- [ ] **Step 8: Commit**

```bash
cd /home/kiet/code/PRM/ble_attendance_mobile
git add .gitignore backend/requirements.txt backend/requirements-dev.txt backend/pytest.ini backend/app backend/tests
git commit -m "refactor(backend): add core package, error format and pytest harness"
```

---

### Task 2: Mô hình dữ liệu và migration Alembic

**Files:**
- Create: `backend/app/models/__init__.py`, `user.py`, `academic.py`, `lecture.py`, `attendance.py`, `leave.py`, `notification.py`
- Create: `backend/alembic.ini`, `backend/alembic/env.py`, `backend/alembic/versions/0001_initial_schema.py`
- Modify: `backend/tests/conftest.py`
- Test: `backend/tests/test_models.py`, `backend/tests/test_migrations.py`

**Interfaces:**
- Consumes: `Base`, `utcnow`, `new_id`.
- Produces: `UserRole`, `User` (`login_id` property), `Course`, `ClassRoom`, `Enrollment`, `LectureSession`, `Detection`, `AttendanceStatus`, `Attendance`, `LeaveStatus`, `LeaveRequest`, `Notification`, tất cả import được từ `app.models`.

- [ ] **Step 1: Viết test thất bại**

`backend/tests/test_models.py`:

```python
import pytest
from sqlalchemy.exc import IntegrityError

from app.models import (
    Attendance,
    ClassRoom,
    Course,
    Enrollment,
    User,
    UserRole,
)


def _user(db, role, **ids):
    user = User(full_name="X", role=role, password_hash="h", **ids)
    db.add(user)
    db.commit()
    return user


def test_login_id_returns_student_or_teacher_id(db):
    student = _user(db, UserRole.student, student_id="25CE099")
    teacher = _user(db, UserRole.teacher, teacher_id="T001")
    assert student.login_id == "25CE099"
    assert teacher.login_id == "T001"


def test_new_user_does_not_need_password_change(db):
    user = _user(db, UserRole.student, student_id="25CE099")
    assert user.must_change_password is False


def test_class_is_unique_per_course_code_semester(db):
    course = Course(code="PRM393", name="Mobile")
    db.add(course)
    db.commit()
    db.add(ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="AAAAAA"))
    db.commit()
    db.add(ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="BBBBBB"))
    with pytest.raises(IntegrityError):
        db.commit()


def test_class_defaults(db):
    course = Course(code="PRM393", name="Mobile")
    db.add(course)
    db.commit()
    cls = ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="AAAAAA")
    db.add(cls)
    db.commit()
    assert cls.max_absence_percent == 20
    assert cls.rssi_threshold == -75
    assert cls.teacher_user_id is None


def test_enrollment_is_unique_per_class_and_student(db):
    course = Course(code="PRM393", name="Mobile")
    student = _user(db, UserRole.student, student_id="25CE099")
    db.add(course)
    db.commit()
    cls = ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="AAAAAA")
    db.add(cls)
    db.commit()
    db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="import"))
    db.commit()
    db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="join_code"))
    with pytest.raises(IntegrityError):
        db.commit()


def test_attendance_is_unique_per_session_and_student(db):
    from app.models import LectureSession

    teacher = _user(db, UserRole.teacher, teacher_id="T001")
    student = _user(db, UserRole.student, student_id="25CE099")
    course = Course(code="PRM393", name="Mobile")
    db.add(course)
    db.commit()
    cls = ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="AAAAAA")
    db.add(cls)
    db.commit()
    session = LectureSession(class_id=cls.id, teacher_user_id=teacher.id, token="t" * 16)
    db.add(session)
    db.commit()
    db.add(Attendance(session_id=session.id, student_user_id=student.id))
    db.commit()
    db.add(Attendance(session_id=session.id, student_user_id=student.id))
    with pytest.raises(IntegrityError):
        db.commit()
```

`backend/tests/test_migrations.py`:

```python
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect

BACKEND = Path(__file__).resolve().parents[1]


def test_upgrade_head_creates_every_table(tmp_path):
    url = f"sqlite:///{tmp_path / 'migrated.db'}"
    cfg = Config(str(BACKEND / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND / "alembic"))
    cfg.set_main_option("sqlalchemy.url", url)

    command.upgrade(cfg, "head")

    tables = set(inspect(create_engine(url)).get_table_names())
    assert {
        "users",
        "courses",
        "classes",
        "enrollments",
        "sessions",
        "detections",
        "attendance",
        "leave_requests",
        "notifications",
    } <= tables
```

- [ ] **Step 2: Chạy test để thấy thất bại**

Run: `cd backend && .venv/bin/pytest tests/test_models.py tests/test_migrations.py -q`
Expected: `ModuleNotFoundError: No module named 'app.models'` / thiếu `alembic.ini`.

- [ ] **Step 3: Viết các model**

`backend/app/models/user.py`:

```python
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
```

`backend/app/models/academic.py`:

```python
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
```

`backend/app/models/lecture.py`:

```python
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
```

`backend/app/models/attendance.py`:

```python
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
```

`backend/app/models/leave.py`:

```python
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
```

`backend/app/models/notification.py`:

```python
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.clock import utcnow
from app.core.database import Base


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    type: Mapped[str] = mapped_column(String(32), nullable=False)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    body: Mapped[str] = mapped_column(String(500), nullable=False)
    ref_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
```

`backend/app/models/__init__.py`:

```python
from app.models.academic import ClassRoom, Course, Enrollment
from app.models.attendance import Attendance, AttendanceStatus
from app.models.lecture import Detection, LectureSession
from app.models.leave import LeaveRequest, LeaveStatus
from app.models.notification import Notification
from app.models.user import User, UserRole

__all__ = [
    "Attendance",
    "AttendanceStatus",
    "ClassRoom",
    "Course",
    "Detection",
    "Enrollment",
    "LeaveRequest",
    "LeaveStatus",
    "LectureSession",
    "Notification",
    "User",
    "UserRole",
]
```

- [ ] **Step 4: Đảm bảo `conftest` nạp model trước khi tạo bảng**

Trong `backend/tests/conftest.py`, thêm sau dòng `from app.main import app`:

```python
from app import models as _models  # noqa: F401  (đăng ký bảng vào Base.metadata)
```

- [ ] **Step 5: Chạy test model**

Run: `.venv/bin/pytest tests/test_models.py -q`
Expected: `6 passed`.

- [ ] **Step 6: Khởi tạo Alembic**

```bash
cd backend
.venv/bin/alembic init alembic
```
Sau đó thay toàn bộ `backend/alembic/env.py` bằng:

```python
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

import app.models  # noqa: F401
from app.core.config import settings
from app.core.database import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name, disable_existing_loggers=False)
if not config.get_main_option("sqlalchemy.url"):
    config.set_main_option("sqlalchemy.url", settings.database_url.replace("%", "%%"))

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            render_as_batch=connection.dialect.name == "sqlite",
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```
Trong `backend/alembic.ini`, đảm bảo dòng `sqlalchemy.url =` để trống (xóa URL mặc định `driver://...`).

- [ ] **Step 7: Sinh migration baseline**

```bash
DATABASE_URL_OVERRIDE=sqlite:///./autogen.db .venv/bin/alembic revision --autogenerate -m "initial schema" --rev-id 0001
rm -f autogen.db
```
Mở `backend/alembic/versions/0001_initial_schema.py`, kiểm tra có đủ 9 bảng (`users`, `courses`, `classes`, `enrollments`, `sessions`, `detections`, `attendance`, `leave_requests`, `notifications`) và index `ix_detections_lookup`. Đổi tên file nếu Alembic đặt khác (`0001_initial_schema.py`).

- [ ] **Step 8: Chạy test migration**

Run: `.venv/bin/pytest tests/test_migrations.py -q`
Expected: `1 passed`.

- [ ] **Step 9: Chạy lại toàn bộ test**

Run: `.venv/bin/pytest -q`
Expected: tất cả đạt (14 passed).

- [ ] **Step 10: Commit**

```bash
cd /home/kiet/code/PRM/ble_attendance_mobile
git add backend/app/models backend/alembic backend/alembic.ini backend/tests
git commit -m "feat(backend): domain models and baseline alembic migration"
```

---

### Task 3: Bảo mật và router xác thực

**Files:**
- Create: `backend/app/core/security.py`, `backend/app/core/validators.py`
- Create: `backend/app/schemas/__init__.py`, `backend/app/schemas/auth.py`
- Create: `backend/app/routers/__init__.py`, `backend/app/routers/auth.py`
- Modify: `backend/app/main.py`, `backend/tests/conftest.py`
- Test: `backend/tests/test_validators.py`, `backend/tests/test_auth.py`

**Interfaces:**
- Consumes: `User`, `UserRole`, `ApiError`, `get_db`.
- Produces: `hash_password(raw) -> str`, `verify_password(raw, hashed) -> bool`, `create_access_token(subject: str) -> str`, `get_current_user` (dependency), `require_roles(*roles) -> dependency` trả `User`; `normalize_id(value) -> str`, `is_valid_student_id(value) -> bool`; schemas `RegisterRequest`, `LoginRequest`, `TokenResponse`, `UserOut`, `ChangePasswordRequest`; fixtures `make_user(role, ident, name=None, password="Pass@123", must_change=False)`, `auth(user) -> headers`.

- [ ] **Step 1: Viết test thất bại**

Thêm vào `backend/tests/conftest.py` (phía dưới các fixture hiện có; thêm import ở đầu file):

```python
from app.core.security import create_access_token, hash_password
from app.models import User, UserRole


@pytest.fixture()
def make_user(db):
    def _make(role, ident, name=None, password="Pass@123", must_change=False):
        ids = {"student_id": ident} if role == UserRole.student else {"teacher_id": ident}
        user = User(
            full_name=name or ident,
            role=role,
            password_hash=hash_password(password),
            must_change_password=must_change,
            **ids,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    return _make


@pytest.fixture()
def auth():
    def _auth(user):
        return {"Authorization": f"Bearer {create_access_token(user.id)}"}

    return _auth
```

`backend/tests/test_validators.py`:

```python
import pytest

from app.core.validators import is_valid_student_id, normalize_id


@pytest.mark.parametrize("value", ["25CE099", "D26CE045", "24SE001", "25ABC123"])
def test_valid_student_ids(value):
    assert is_valid_student_id(value)


@pytest.mark.parametrize("value", ["", "25ce099", "T001", "2CE099", "25CE99", "D26C045"])
def test_invalid_student_ids(value):
    assert not is_valid_student_id(value)


def test_normalize_id_strips_and_uppercases():
    assert normalize_id("  25ce099 ") == "25CE099"
```

`backend/tests/test_auth.py`:

```python
from app.models import UserRole


def test_register_creates_student(client):
    response = client.post(
        "/auth/register",
        json={"full_name": "Nguyen Van A", "identifier": "25CE099", "password": "Pass@123"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["role"] == "student"
    assert body["student_id"] == "25CE099"
    assert body["must_change_password"] is False


def test_register_normalizes_identifier(client):
    response = client.post(
        "/auth/register",
        json={"full_name": "Nguyen Van A", "identifier": " 25ce099 ", "password": "Pass@123"},
    )
    assert response.status_code == 201
    assert response.json()["student_id"] == "25CE099"


def test_register_ignores_role_in_payload(client):
    for role in ("admin", "teacher"):
        response = client.post(
            "/auth/register",
            json={
                "full_name": "Hacker",
                "identifier": "25CE100" if role == "admin" else "25CE101",
                "password": "Pass@123",
                "role": role,
            },
        )
        assert response.status_code == 201
        assert response.json()["role"] == "student"


def test_register_rejects_bad_student_id(client):
    response = client.post(
        "/auth/register",
        json={"full_name": "Nguyen Van A", "identifier": "T001", "password": "Pass@123"},
    )
    assert response.status_code == 422
    assert response.json()["code"] == "invalid_student_id"


def test_register_rejects_duplicate(client):
    payload = {"full_name": "Nguyen Van A", "identifier": "25CE099", "password": "Pass@123"}
    assert client.post("/auth/register", json=payload).status_code == 201
    response = client.post("/auth/register", json=payload)
    assert response.status_code == 409
    assert response.json()["code"] == "student_exists"


def test_login_success_returns_token_and_flag(client, make_user):
    make_user(UserRole.teacher, "T001", must_change=True)
    response = client.post("/auth/login", json={"identifier": "T001", "password": "Pass@123"})
    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["must_change_password"] is True


def test_login_accepts_lowercase_and_spaces(client, make_user):
    make_user(UserRole.student, "25CE099")
    response = client.post("/auth/login", json={"identifier": " 25ce099 ", "password": "Pass@123"})
    assert response.status_code == 200


def test_login_wrong_password(client, make_user):
    make_user(UserRole.teacher, "T001")
    response = client.post("/auth/login", json={"identifier": "T001", "password": "nope-nope"})
    assert response.status_code == 401
    assert response.json()["code"] == "invalid_credentials"


def test_me_requires_token(client):
    response = client.get("/auth/me")
    assert response.status_code == 401
    assert response.json()["code"] == "not_authenticated"


def test_me_returns_role(client, make_user, auth):
    admin = make_user(UserRole.admin, "A001", name="Admin")
    response = client.get("/auth/me", headers=auth(admin))
    assert response.status_code == 200
    assert response.json()["role"] == "admin"
    assert response.json()["teacher_id"] == "A001"


def test_me_rejects_garbage_token(client):
    response = client.get("/auth/me", headers={"Authorization": "Bearer garbage"})
    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"


def test_change_password_clears_flag(client, make_user, auth):
    teacher = make_user(UserRole.teacher, "T001", must_change=True)
    response = client.post(
        "/auth/change-password",
        json={"old_password": "Pass@123", "new_password": "NewPass@456"},
        headers=auth(teacher),
    )
    assert response.status_code == 200
    login = client.post("/auth/login", json={"identifier": "T001", "password": "NewPass@456"})
    assert login.status_code == 200
    assert login.json()["must_change_password"] is False


def test_change_password_wrong_old_password(client, make_user, auth):
    teacher = make_user(UserRole.teacher, "T001")
    response = client.post(
        "/auth/change-password",
        json={"old_password": "wrong-old", "new_password": "NewPass@456"},
        headers=auth(teacher),
    )
    assert response.status_code == 400
    assert response.json()["code"] == "invalid_password"
```

- [ ] **Step 2: Chạy test để thấy thất bại**

Run: `.venv/bin/pytest tests/test_validators.py tests/test_auth.py -q`
Expected: `ModuleNotFoundError: No module named 'app.core.security'`.

- [ ] **Step 3: Viết `validators` và `security`**

`backend/app/core/validators.py`:

```python
import re

STUDENT_ID_PATTERN = re.compile(r"^(?:\d{2}[A-Z]{2,3}\d{3}|D\d{2}[A-Z]{2,3}\d{3})$")


def normalize_id(value: str) -> str:
    return value.strip().upper()


def is_valid_student_id(value: str) -> bool:
    return STUDENT_ID_PATTERN.match(value) is not None
```

`backend/app/core/security.py`:

```python
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


def get_current_user(token: str | None = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
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


def require_roles(*roles: UserRole):
    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise ApiError(403, "forbidden", "Bạn không có quyền thực hiện thao tác này")
        return user

    return checker
```

- [ ] **Step 4: Viết schemas và router**

`backend/app/schemas/__init__.py` và `backend/app/routers/__init__.py` để trống.

`backend/app/schemas/auth.py`:

```python
from pydantic import BaseModel, ConfigDict, Field

from app.models import UserRole


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    identifier: str = Field(min_length=4, max_length=16)
    password: str = Field(min_length=6, max_length=128)


class LoginRequest(BaseModel):
    identifier: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    must_change_password: bool = False


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    role: UserRole
    student_id: str | None
    teacher_id: str | None
    must_change_password: bool


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(min_length=6, max_length=128)
```

`backend/app/routers/auth.py`:

```python
from fastapi import APIRouter, Depends
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import create_access_token, get_current_user, hash_password, verify_password
from app.core.validators import is_valid_student_id, normalize_id
from app.models import User, UserRole
from app.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut, status_code=201)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> User:
    identifier = normalize_id(payload.identifier)
    if not is_valid_student_id(identifier):
        raise ApiError(422, "invalid_student_id", "Mã sinh viên phải có dạng 25CE099 hoặc D26CE045")
    if db.scalar(select(User.id).where(User.student_id == identifier)) is not None:
        raise ApiError(409, "student_exists", "Mã sinh viên đã tồn tại")
    user = User(
        full_name=payload.full_name.strip(),
        role=UserRole.student,
        student_id=identifier,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    identifier = normalize_id(payload.identifier)
    user = db.scalar(select(User).where(or_(User.student_id == identifier, User.teacher_id == identifier)))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise ApiError(401, "invalid_credentials", "Sai mã đăng nhập hoặc mật khẩu")
    return TokenResponse(
        access_token=create_access_token(user.id),
        must_change_password=user.must_change_password,
    )


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)) -> User:
    return user


@router.post("/change-password")
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict[str, str]:
    if not verify_password(payload.old_password, user.password_hash):
        raise ApiError(400, "invalid_password", "Mật khẩu hiện tại không đúng")
    user.password_hash = hash_password(payload.new_password)
    user.must_change_password = False
    db.commit()
    return {"message": "ok"}
```

Trong `backend/app/main.py` thêm:

```python
from app.routers import auth as auth_router
```
và sau `register_error_handlers(app)`:

```python
app.include_router(auth_router.router)
```

- [ ] **Step 5: Chạy test**

Run: `.venv/bin/pytest -q`
Expected: tất cả đạt.

- [ ] **Step 6: Commit**

```bash
git add backend/app backend/tests
git commit -m "feat(backend): auth with /me, change-password and role guard"
```

---

### Task 4: Dịch vụ presence (logic thuần)

**Files:**
- Create: `backend/app/services/__init__.py`, `backend/app/services/presence.py`
- Test: `backend/tests/test_presence.py`

**Interfaces:**
- Produces:
  - `WINDOW_SECONDS = 30`, `PRESENT_THRESHOLD = 0.6`, `Sample = tuple[datetime, int]`
  - `total_windows(starts_at, ends_at) -> int`
  - `window_index(starts_at, moment) -> int`
  - `valid_window_count(starts_at, ends_at, samples, rssi_threshold) -> int`
  - `presence_ratio(starts_at, ends_at, samples, rssi_threshold) -> float`
  - `first_seen_at(samples, starts_at, ends_at, rssi_threshold) -> datetime | None`

- [ ] **Step 1: Viết test thất bại**

`backend/tests/test_presence.py`:

```python
from datetime import datetime, timedelta

import pytest

from app.services.presence import (
    first_seen_at,
    presence_ratio,
    total_windows,
    valid_window_count,
)

START = datetime(2026, 10, 18, 3, 0, 0)
THRESHOLD = -75


def at(seconds):
    return START + timedelta(seconds=seconds)


@pytest.mark.parametrize("duration,expected", [(0, 1), (30, 1), (90, 3), (91, 4)])
def test_total_windows(duration, expected):
    assert total_windows(START, at(duration)) == expected


def test_ratio_counts_windows_not_packets():
    samples = [(at(s), -60) for s in (1, 5, 10, 15, 20, 65, 70)]
    assert valid_window_count(START, at(90), samples, THRESHOLD) == 2
    assert presence_ratio(START, at(90), samples, THRESHOLD) == 0.667


def test_many_packets_in_one_window_count_once():
    samples = [(at(1 + i * 0.1), -60) for i in range(100)]
    assert presence_ratio(START, at(90), samples, THRESHOLD) == 0.333


def test_window_with_weak_median_is_invalid():
    samples = [(at(s), r) for s, r in [(1, -60), (2, -60), (3, -95), (4, -95), (5, -95)]]
    assert presence_ratio(START, at(30), samples, THRESHOLD) == 0.0


def test_threshold_is_strict():
    assert presence_ratio(START, at(30), [(at(1), -75)], THRESHOLD) == 0.0
    assert presence_ratio(START, at(30), [(at(1), -74)], THRESHOLD) == 1.0


def test_samples_outside_session_are_ignored():
    samples = [(at(-5), -50), (at(90), -50), (at(500), -50)]
    assert presence_ratio(START, at(90), samples, THRESHOLD) == 0.0


def test_no_samples_gives_zero():
    assert presence_ratio(START, at(300), [], THRESHOLD) == 0.0


def test_ratio_never_exceeds_one():
    samples = [(at(w * 30 + 1), -50) for w in range(3)]
    assert presence_ratio(START, at(90), samples, THRESHOLD) == 1.0


def test_first_seen_ignores_weak_and_out_of_session_samples():
    samples = [(at(-10), -50), (at(5), -95), (at(40), -60), (at(70), -60)]
    assert first_seen_at(samples, START, at(90), THRESHOLD) == at(40)


def test_first_seen_none_without_valid_samples():
    assert first_seen_at([(at(5), -95)], START, at(90), THRESHOLD) is None
```

- [ ] **Step 2: Chạy test để thấy thất bại**

Run: `.venv/bin/pytest tests/test_presence.py -q`
Expected: `ModuleNotFoundError: No module named 'app.services'`.

- [ ] **Step 3: Cài đặt**

`backend/app/services/__init__.py` để trống.

`backend/app/services/presence.py`:

```python
import math
from datetime import datetime
from statistics import median

WINDOW_SECONDS = 30
PRESENT_THRESHOLD = 0.6

Sample = tuple[datetime, int]


def total_windows(starts_at: datetime, ends_at: datetime) -> int:
    seconds = (ends_at - starts_at).total_seconds()
    return max(1, math.ceil(seconds / WINDOW_SECONDS))


def window_index(starts_at: datetime, moment: datetime) -> int:
    return math.floor((moment - starts_at).total_seconds() / WINDOW_SECONDS)


def valid_window_count(
    starts_at: datetime,
    ends_at: datetime,
    samples: list[Sample],
    rssi_threshold: int,
) -> int:
    total = total_windows(starts_at, ends_at)
    buckets: dict[int, list[int]] = {}
    for moment, rssi in samples:
        index = window_index(starts_at, moment)
        if 0 <= index < total:
            buckets.setdefault(index, []).append(rssi)
    return sum(1 for values in buckets.values() if median(values) > rssi_threshold)


def presence_ratio(
    starts_at: datetime,
    ends_at: datetime,
    samples: list[Sample],
    rssi_threshold: int,
) -> float:
    valid = valid_window_count(starts_at, ends_at, samples, rssi_threshold)
    return min(1.0, round(valid / total_windows(starts_at, ends_at), 3))


def first_seen_at(
    samples: list[Sample],
    starts_at: datetime,
    ends_at: datetime,
    rssi_threshold: int,
) -> datetime | None:
    moments = [
        moment
        for moment, rssi in samples
        if starts_at <= moment <= ends_at and rssi > rssi_threshold
    ]
    return min(moments) if moments else None
```

- [ ] **Step 4: Chạy test**

Run: `.venv/bin/pytest tests/test_presence.py -q`
Expected: `13 passed`.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services backend/tests/test_presence.py
git commit -m "feat(backend): window-based presence ratio with median RSSI"
```

---

### Task 5: Dịch vụ beacon (HMAC tag)

**Files:**
- Create: `backend/app/services/beacon.py`
- Test: `backend/tests/test_beacon.py`

**Interfaces:**
- Produces:
  - `BUCKET_SECONDS = 30`, `TAG_LENGTH = 8`
  - `bucket_of(moment: datetime) -> int` (naive hiểu là UTC)
  - `student_secret(session_id: str, student_id: str) -> str`
  - `make_tag(secret: str, bucket: int) -> str`
  - `verify_tag(secret: str, bucket: int, tag: str, observed_at: datetime) -> bool`
- Ghi chú cho Flutter (Plan 5): client phải tái hiện đúng `make_tag` (HMAC-SHA256, key = `secret` UTF-8, message = `str(bucket)` UTF-8, lấy 8 ký tự hex đầu) — các vector test bên dưới là chuẩn đối chiếu.

- [ ] **Step 1: Viết test thất bại**

`backend/tests/test_beacon.py`:

```python
from datetime import datetime, timedelta

from app.services.beacon import bucket_of, make_tag, student_secret, verify_tag

OBSERVED = datetime(2026, 10, 18, 0, 0, 0)


def test_bucket_of_known_value():
    assert bucket_of(OBSERVED) == 59742720
    assert bucket_of(OBSERVED + timedelta(seconds=29)) == 59742720
    assert bucket_of(OBSERVED + timedelta(seconds=30)) == 59742721


def test_make_tag_known_vector():
    assert make_tag("abc", 100) == "a18217a4"


def test_student_secret_known_vector():
    # BEACON_SERVER_KEY=key được đặt trong tests/conftest.py
    assert student_secret("sess-1", "25CE099") == (
        "a28f493f3749b2e8b46830fd47be832c359f7d9fc2177827c8fd4bddd2628f59"
    )


def test_verify_accepts_current_and_adjacent_buckets():
    secret = student_secret("s", "25CE099")
    current = bucket_of(OBSERVED)
    for bucket in (current - 1, current, current + 1):
        assert verify_tag(secret, bucket, make_tag(secret, bucket), OBSERVED)


def test_verify_rejects_bucket_two_away():
    secret = student_secret("s", "25CE099")
    bucket = bucket_of(OBSERVED) + 2
    assert not verify_tag(secret, bucket, make_tag(secret, bucket), OBSERVED)


def test_verify_rejects_wrong_tag_and_wrong_secret():
    secret = student_secret("s", "25CE099")
    bucket = bucket_of(OBSERVED)
    assert not verify_tag(secret, bucket, "00000000", OBSERVED)
    other = student_secret("s", "25CE100")
    assert not verify_tag(secret, bucket, make_tag(other, bucket), OBSERVED)


def test_verify_is_case_insensitive_for_hex():
    secret = student_secret("s", "25CE099")
    bucket = bucket_of(OBSERVED)
    assert verify_tag(secret, bucket, make_tag(secret, bucket).upper(), OBSERVED)
```

- [ ] **Step 2: Chạy test để thấy thất bại**

Run: `.venv/bin/pytest tests/test_beacon.py -q`
Expected: `ModuleNotFoundError: No module named 'app.services.beacon'`.

- [ ] **Step 3: Cài đặt**

`backend/app/services/beacon.py`:

```python
import hashlib
import hmac
from datetime import datetime, timezone

from app.core.config import settings

BUCKET_SECONDS = 30
TAG_LENGTH = 8


def bucket_of(moment: datetime) -> int:
    aware = moment.replace(tzinfo=timezone.utc) if moment.tzinfo is None else moment
    return int(aware.timestamp() // BUCKET_SECONDS)


def student_secret(session_id: str, student_id: str) -> str:
    return hmac.new(
        settings.beacon_server_key.encode(),
        f"{session_id}:{student_id}".encode(),
        hashlib.sha256,
    ).hexdigest()


def make_tag(secret: str, bucket: int) -> str:
    digest = hmac.new(secret.encode(), str(bucket).encode(), hashlib.sha256).hexdigest()
    return digest[:TAG_LENGTH]


def verify_tag(secret: str, bucket: int, tag: str, observed_at: datetime) -> bool:
    if abs(bucket - bucket_of(observed_at)) > 1:
        return False
    return hmac.compare_digest(make_tag(secret, bucket), tag.lower())
```

- [ ] **Step 4: Chạy test**

Run: `.venv/bin/pytest tests/test_beacon.py -q`
Expected: `7 passed`.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/beacon.py backend/tests/test_beacon.py
git commit -m "feat(backend): HMAC beacon tags bound to session and student"
```

---

### Task 6: Router Admin (môn, lớp, giảng viên)

**Files:**
- Create: `backend/app/schemas/admin.py`, `backend/app/schemas/classes.py`
- Create: `backend/app/services/academic.py`
- Create: `backend/app/routers/admin.py`
- Modify: `backend/app/main.py`, `backend/tests/conftest.py`
- Test: `backend/tests/test_admin.py`

**Interfaces:**
- Consumes: `require_roles`, `hash_password`, `normalize_id`, models, `UserOut`.
- Produces:
  - `schemas.classes.ClassOut(id, course_id, course_code, course_name, class_code, semester, teacher_user_id, teacher_name, join_code: str | None, max_absence_percent, rssi_threshold, student_count)`, `StudentOut(id, student_id, full_name)`
  - `services.academic.new_join_code(db) -> str`, `services.academic.class_to_out(db, cls, include_join_code=True) -> ClassOut`
  - Endpoint (chỉ admin): `POST/GET /admin/courses`, `PATCH/DELETE /admin/courses/{id}`, `POST/GET /admin/classes`, `PATCH/DELETE /admin/classes/{id}`, `POST /admin/classes/{id}/assign-teacher`, `POST/GET /admin/teachers`, `POST /admin/users/{id}/reset-password`
  - Fixtures `make_class(teacher=None, course_code="PRM393", class_code="SE1901", semester="FA26", rssi_threshold=-75) -> ClassRoom`, `enroll(cls, *students, source="import")`

- [ ] **Step 1: Viết test thất bại**

Thêm vào `backend/tests/conftest.py` (kèm import `from sqlalchemy import func, select` và `from app.models import ClassRoom, Course, Enrollment`):

```python
@pytest.fixture()
def make_class(db):
    def _make(teacher=None, course_code="PRM393", class_code="SE1901", semester="FA26", rssi_threshold=-75):
        course = db.scalar(select(Course).where(Course.code == course_code))
        if course is None:
            course = Course(code=course_code, name="Mobile Programming")
            db.add(course)
            db.flush()
        number = db.scalar(select(func.count(ClassRoom.id))) or 0
        cls = ClassRoom(
            course_id=course.id,
            class_code=class_code,
            semester=semester,
            teacher_user_id=teacher.id if teacher else None,
            join_code=f"J{number:05d}",
            rssi_threshold=rssi_threshold,
        )
        db.add(cls)
        db.commit()
        db.refresh(cls)
        return cls

    return _make


@pytest.fixture()
def enroll(db):
    def _enroll(cls, *students, source="import"):
        for student in students:
            db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source=source))
        db.commit()

    return _enroll
```

`backend/tests/test_admin.py`:

```python
import pytest

from app.models import UserRole


@pytest.fixture()
def admin(make_user):
    return make_user(UserRole.admin, "A001")


def test_non_admin_is_forbidden(client, make_user, auth):
    for role, ident in ((UserRole.teacher, "T001"), (UserRole.student, "25CE099")):
        user = make_user(role, ident)
        response = client.get("/admin/courses", headers=auth(user))
        assert response.status_code == 403
        assert response.json()["code"] == "forbidden"


def test_anonymous_is_unauthorized(client):
    assert client.get("/admin/courses").status_code == 401


def test_course_crud(client, admin, auth):
    created = client.post(
        "/admin/courses",
        json={"code": "prm393", "name": "Mobile Programming", "credits": 3},
        headers=auth(admin),
    )
    assert created.status_code == 201
    course = created.json()
    assert course["code"] == "PRM393"

    duplicate = client.post(
        "/admin/courses", json={"code": "PRM393", "name": "Other"}, headers=auth(admin)
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "course_exists"

    updated = client.patch(
        f"/admin/courses/{course['id']}", json={"name": "Mobile Dev"}, headers=auth(admin)
    )
    assert updated.json()["name"] == "Mobile Dev"

    assert [c["code"] for c in client.get("/admin/courses", headers=auth(admin)).json()] == ["PRM393"]
    assert client.delete(f"/admin/courses/{course['id']}", headers=auth(admin)).status_code == 204


def test_cannot_delete_course_with_classes(client, admin, auth, make_class):
    cls = make_class()
    response = client.delete(f"/admin/courses/{cls.course_id}", headers=auth(admin))
    assert response.status_code == 409
    assert response.json()["code"] == "course_has_classes"


def test_create_class_with_teacher(client, admin, auth, make_user):
    teacher = make_user(UserRole.teacher, "T001", name="Co Lan")
    course = client.post(
        "/admin/courses", json={"code": "PRM393", "name": "Mobile"}, headers=auth(admin)
    ).json()
    response = client.post(
        "/admin/classes",
        json={
            "course_id": course["id"],
            "class_code": "SE1901",
            "semester": "FA26",
            "teacher_user_id": teacher.id,
        },
        headers=auth(admin),
    )
    assert response.status_code == 201
    body = response.json()
    assert body["course_code"] == "PRM393"
    assert body["teacher_name"] == "Co Lan"
    assert len(body["join_code"]) == 6
    assert body["max_absence_percent"] == 20
    assert body["rssi_threshold"] == -75
    assert body["student_count"] == 0


def test_create_class_rejects_duplicate_and_unknown_refs(client, admin, auth, make_class, make_user):
    cls = make_class()
    duplicate = client.post(
        "/admin/classes",
        json={"course_id": cls.course_id, "class_code": "SE1901", "semester": "FA26"},
        headers=auth(admin),
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "class_exists"

    missing_course = client.post(
        "/admin/classes",
        json={"course_id": "nope", "class_code": "X", "semester": "FA26"},
        headers=auth(admin),
    )
    assert missing_course.status_code == 404
    assert missing_course.json()["code"] == "course_not_found"

    student = make_user(UserRole.student, "25CE099")
    not_teacher = client.post(
        "/admin/classes",
        json={
            "course_id": cls.course_id,
            "class_code": "SE1902",
            "semester": "FA26",
            "teacher_user_id": student.id,
        },
        headers=auth(admin),
    )
    assert not_teacher.status_code == 404
    assert not_teacher.json()["code"] == "teacher_not_found"


def test_assign_teacher(client, admin, auth, make_user, make_class):
    cls = make_class()
    teacher = make_user(UserRole.teacher, "T001", name="Co Lan")
    response = client.post(
        f"/admin/classes/{cls.id}/assign-teacher",
        json={"teacher_user_id": teacher.id},
        headers=auth(admin),
    )
    assert response.status_code == 200
    assert response.json()["teacher_user_id"] == teacher.id


def test_update_class_settings(client, admin, auth, make_class):
    cls = make_class()
    response = client.patch(
        f"/admin/classes/{cls.id}",
        json={"rssi_threshold": -70, "max_absence_percent": 25},
        headers=auth(admin),
    )
    assert response.status_code == 200
    assert response.json()["rssi_threshold"] == -70
    assert response.json()["max_absence_percent"] == 25


def test_cannot_delete_class_with_students(client, admin, auth, make_class, make_user, enroll):
    cls = make_class()
    enroll(cls, make_user(UserRole.student, "25CE099"))
    response = client.delete(f"/admin/classes/{cls.id}", headers=auth(admin))
    assert response.status_code == 409
    assert response.json()["code"] == "class_not_empty"


def test_delete_empty_class(client, admin, auth, make_class):
    cls = make_class()
    assert client.delete(f"/admin/classes/{cls.id}", headers=auth(admin)).status_code == 204


def test_create_teacher_has_temp_password(client, admin, auth):
    response = client.post(
        "/admin/teachers", json={"teacher_id": "t002", "full_name": "Thay Nam"}, headers=auth(admin)
    )
    assert response.status_code == 201
    assert response.json()["teacher_id"] == "T002"
    assert response.json()["must_change_password"] is True

    login = client.post("/auth/login", json={"identifier": "T002", "password": "T002"})
    assert login.status_code == 200
    assert login.json()["must_change_password"] is True

    duplicate = client.post(
        "/admin/teachers", json={"teacher_id": "T002", "full_name": "Other"}, headers=auth(admin)
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "teacher_exists"


def test_list_teachers_only_returns_teachers(client, admin, auth, make_user):
    make_user(UserRole.teacher, "T001")
    make_user(UserRole.student, "25CE099")
    ids = [t["teacher_id"] for t in client.get("/admin/teachers", headers=auth(admin)).json()]
    assert ids == ["T001"]


def test_reset_password_restores_temp_password(client, admin, auth, make_user):
    student = make_user(UserRole.student, "25CE099", password="Changed@1")
    response = client.post(f"/admin/users/{student.id}/reset-password", headers=auth(admin))
    assert response.status_code == 200
    login = client.post("/auth/login", json={"identifier": "25CE099", "password": "25CE099"})
    assert login.status_code == 200
    assert login.json()["must_change_password"] is True
```

- [ ] **Step 2: Chạy test để thấy thất bại**

Run: `.venv/bin/pytest tests/test_admin.py -q`
Expected: 404 trên các endpoint `/admin/...` (router chưa tồn tại).

- [ ] **Step 3: Cài đặt schemas và service**

`backend/app/schemas/classes.py`:

```python
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
```

`backend/app/schemas/admin.py`:

```python
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
```

`backend/app/services/academic.py`:

```python
import secrets

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import ClassRoom, Enrollment
from app.schemas.classes import ClassOut


def new_join_code(db: Session) -> str:
    while True:
        code = secrets.token_hex(3).upper()
        if db.scalar(select(ClassRoom.id).where(ClassRoom.join_code == code)) is None:
            return code


def class_to_out(db: Session, cls: ClassRoom, include_join_code: bool = True) -> ClassOut:
    count = db.scalar(select(func.count(Enrollment.id)).where(Enrollment.class_id == cls.id)) or 0
    return ClassOut(
        id=cls.id,
        course_id=cls.course_id,
        course_code=cls.course.code,
        course_name=cls.course.name,
        class_code=cls.class_code,
        semester=cls.semester,
        teacher_user_id=cls.teacher_user_id,
        teacher_name=cls.teacher.full_name if cls.teacher else None,
        join_code=cls.join_code if include_join_code else None,
        max_absence_percent=cls.max_absence_percent,
        rssi_threshold=cls.rssi_threshold,
        student_count=count,
    )
```

- [ ] **Step 4: Cài đặt router Admin**

`backend/app/routers/admin.py`:

```python
from fastapi import APIRouter, Depends, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import hash_password, require_roles
from app.core.validators import normalize_id
from app.models import ClassRoom, Course, Enrollment, LectureSession, User, UserRole
from app.schemas.admin import (
    AssignTeacherIn,
    ClassCreate,
    ClassUpdate,
    CourseIn,
    CourseOut,
    CourseUpdate,
    TeacherCreate,
)
from app.schemas.auth import UserOut
from app.schemas.classes import ClassOut
from app.services.academic import class_to_out, new_join_code

router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(require_roles(UserRole.admin))],
)


def _get_course(db: Session, course_id: str) -> Course:
    course = db.get(Course, course_id)
    if course is None:
        raise ApiError(404, "course_not_found", "Không tìm thấy môn học")
    return course


def _get_class(db: Session, class_id: str) -> ClassRoom:
    cls = db.get(ClassRoom, class_id)
    if cls is None:
        raise ApiError(404, "class_not_found", "Không tìm thấy lớp")
    return cls


def _get_teacher(db: Session, teacher_user_id: str) -> User:
    teacher = db.get(User, teacher_user_id)
    if teacher is None or teacher.role != UserRole.teacher:
        raise ApiError(404, "teacher_not_found", "Không tìm thấy giảng viên")
    return teacher


@router.post("/courses", response_model=CourseOut, status_code=201)
def create_course(payload: CourseIn, db: Session = Depends(get_db)) -> Course:
    code = payload.code.strip().upper()
    if db.scalar(select(Course.id).where(Course.code == code)) is not None:
        raise ApiError(409, "course_exists", "Mã môn học đã tồn tại")
    course = Course(code=code, name=payload.name.strip(), credits=payload.credits)
    db.add(course)
    db.commit()
    db.refresh(course)
    return course


@router.get("/courses", response_model=list[CourseOut])
def list_courses(db: Session = Depends(get_db)) -> list[Course]:
    return list(db.scalars(select(Course).order_by(Course.code)))


@router.patch("/courses/{course_id}", response_model=CourseOut)
def update_course(course_id: str, payload: CourseUpdate, db: Session = Depends(get_db)) -> Course:
    course = _get_course(db, course_id)
    if payload.name is not None:
        course.name = payload.name.strip()
    if payload.credits is not None:
        course.credits = payload.credits
    db.commit()
    db.refresh(course)
    return course


@router.delete("/courses/{course_id}", status_code=204)
def delete_course(course_id: str, db: Session = Depends(get_db)) -> Response:
    course = _get_course(db, course_id)
    if db.scalar(select(ClassRoom.id).where(ClassRoom.course_id == course.id)) is not None:
        raise ApiError(409, "course_has_classes", "Môn học đang có lớp, không thể xóa")
    db.delete(course)
    db.commit()
    return Response(status_code=204)


@router.post("/classes", response_model=ClassOut, status_code=201)
def create_class(payload: ClassCreate, db: Session = Depends(get_db)) -> ClassOut:
    _get_course(db, payload.course_id)
    if payload.teacher_user_id is not None:
        _get_teacher(db, payload.teacher_user_id)
    class_code = payload.class_code.strip().upper()
    duplicate = db.scalar(
        select(ClassRoom.id).where(
            ClassRoom.course_id == payload.course_id,
            ClassRoom.class_code == class_code,
            ClassRoom.semester == payload.semester,
        )
    )
    if duplicate is not None:
        raise ApiError(409, "class_exists", "Lớp này đã tồn tại trong học kỳ")
    cls = ClassRoom(
        course_id=payload.course_id,
        class_code=class_code,
        semester=payload.semester.strip(),
        teacher_user_id=payload.teacher_user_id,
        join_code=new_join_code(db),
        max_absence_percent=payload.max_absence_percent,
        rssi_threshold=payload.rssi_threshold,
    )
    db.add(cls)
    db.commit()
    db.refresh(cls)
    return class_to_out(db, cls)


@router.get("/classes", response_model=list[ClassOut])
def list_classes(db: Session = Depends(get_db)) -> list[ClassOut]:
    stmt = (
        select(ClassRoom)
        .join(Course, ClassRoom.course_id == Course.id)
        .order_by(Course.code, ClassRoom.class_code)
    )
    return [class_to_out(db, cls) for cls in db.scalars(stmt)]


@router.patch("/classes/{class_id}", response_model=ClassOut)
def update_class(class_id: str, payload: ClassUpdate, db: Session = Depends(get_db)) -> ClassOut:
    cls = _get_class(db, class_id)
    if payload.class_code is not None:
        cls.class_code = payload.class_code.strip().upper()
    if payload.semester is not None:
        cls.semester = payload.semester.strip()
    if payload.max_absence_percent is not None:
        cls.max_absence_percent = payload.max_absence_percent
    if payload.rssi_threshold is not None:
        cls.rssi_threshold = payload.rssi_threshold
    db.commit()
    db.refresh(cls)
    return class_to_out(db, cls)


@router.delete("/classes/{class_id}", status_code=204)
def delete_class(class_id: str, db: Session = Depends(get_db)) -> Response:
    cls = _get_class(db, class_id)
    has_sessions = db.scalar(select(LectureSession.id).where(LectureSession.class_id == cls.id))
    has_students = db.scalar(select(Enrollment.id).where(Enrollment.class_id == cls.id))
    if has_sessions is not None or has_students is not None:
        raise ApiError(409, "class_not_empty", "Lớp đã có sinh viên hoặc buổi học, không thể xóa")
    db.delete(cls)
    db.commit()
    return Response(status_code=204)


@router.post("/classes/{class_id}/assign-teacher", response_model=ClassOut)
def assign_teacher(class_id: str, payload: AssignTeacherIn, db: Session = Depends(get_db)) -> ClassOut:
    cls = _get_class(db, class_id)
    teacher = _get_teacher(db, payload.teacher_user_id)
    active = db.scalar(
        select(LectureSession.id).where(
            LectureSession.class_id == cls.id, LectureSession.is_active.is_(True)
        )
    )
    if active is not None and cls.teacher_user_id != teacher.id:
        raise ApiError(409, "class_has_active_session", "Lớp đang có buổi học, chưa thể đổi giảng viên")
    cls.teacher_user_id = teacher.id
    db.commit()
    db.refresh(cls)
    return class_to_out(db, cls)


@router.post("/teachers", response_model=UserOut, status_code=201)
def create_teacher(payload: TeacherCreate, db: Session = Depends(get_db)) -> User:
    teacher_id = normalize_id(payload.teacher_id)
    if db.scalar(select(User.id).where(User.teacher_id == teacher_id)) is not None:
        raise ApiError(409, "teacher_exists", "Mã giảng viên đã tồn tại")
    teacher = User(
        full_name=payload.full_name.strip(),
        role=UserRole.teacher,
        teacher_id=teacher_id,
        password_hash=hash_password(teacher_id),
        must_change_password=True,
    )
    db.add(teacher)
    db.commit()
    db.refresh(teacher)
    return teacher


@router.get("/teachers", response_model=list[UserOut])
def list_teachers(db: Session = Depends(get_db)) -> list[User]:
    return list(db.scalars(select(User).where(User.role == UserRole.teacher).order_by(User.teacher_id)))


@router.post("/users/{user_id}/reset-password")
def reset_password(user_id: str, db: Session = Depends(get_db)) -> dict[str, str]:
    user = db.get(User, user_id)
    if user is None:
        raise ApiError(404, "user_not_found", "Không tìm thấy người dùng")
    user.password_hash = hash_password(user.login_id)
    user.must_change_password = True
    db.commit()
    return {"message": "ok"}
```

Trong `backend/app/main.py` thêm `from app.routers import admin as admin_router` và `app.include_router(admin_router.router)`.

- [ ] **Step 5: Chạy test**

Run: `.venv/bin/pytest -q`
Expected: tất cả đạt.

- [ ] **Step 6: Commit**

```bash
git add backend/app backend/tests
git commit -m "feat(backend): admin API for courses, classes and teachers"
```

---

### Task 7: Lớp của tôi và buổi học theo lớp

**Files:**
- Create: `backend/app/schemas/sessions.py`
- Create: `backend/app/services/access.py`, `backend/app/services/lecture.py`
- Create: `backend/app/routers/classes.py`, `backend/app/routers/sessions.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_classes.py`, `backend/tests/test_sessions.py`

**Interfaces:**
- Consumes: `ClassOut`, `StudentOut`, `JoinClassIn`, `class_to_out`, `student_secret`, `require_roles`.
- Produces:
  - `services.access.get_class_or_404(db, class_id)`, `require_class_access(db, user, cls)`, `get_session_or_404(db, session_id)`, `require_session_teacher(user, session)`
  - `schemas.sessions.SessionOut(id, class_id, class_code, course_code, course_name, teacher_user_id, beacon_code, starts_at, ends_at, is_active, finalization_open, beacon_secret: str | None)`
  - `services.lecture.session_to_out(db, session, beacon_secret=None) -> SessionOut`
  - Endpoint: `GET /classes/mine`, `POST /classes/join`, `GET /classes/{id}`, `GET /classes/{id}/students`, `POST /classes/{id}/sessions`, `GET /classes/{id}/sessions`, `POST /sessions/{id}/end`, `POST /sessions/{id}/open-finalization`, `GET /sessions/active`

- [ ] **Step 1: Viết test thất bại**

`backend/tests/test_classes.py`:

```python
from app.models import UserRole


def test_my_classes_for_each_role(client, make_user, auth, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001", name="Co Lan")
    other_teacher = make_user(UserRole.teacher, "T002")
    admin = make_user(UserRole.admin, "A001")
    student = make_user(UserRole.student, "25CE099")
    mine = make_class(teacher=teacher, class_code="SE1901")
    make_class(teacher=other_teacher, class_code="SE1902")
    enroll(mine, student)

    teacher_view = client.get("/classes/mine", headers=auth(teacher)).json()
    assert [c["class_code"] for c in teacher_view] == ["SE1901"]
    assert teacher_view[0]["join_code"] == mine.join_code
    assert teacher_view[0]["student_count"] == 1

    student_view = client.get("/classes/mine", headers=auth(student)).json()
    assert [c["class_code"] for c in student_view] == ["SE1901"]
    assert student_view[0]["join_code"] is None

    assert len(client.get("/classes/mine", headers=auth(admin)).json()) == 2


def test_join_class_with_code(client, make_user, auth, make_class):
    student = make_user(UserRole.student, "25CE099")
    cls = make_class()
    response = client.post(
        "/classes/join", json={"join_code": cls.join_code.lower()}, headers=auth(student)
    )
    assert response.status_code == 200
    assert response.json()["join_code"] is None

    again = client.post("/classes/join", json={"join_code": cls.join_code}, headers=auth(student))
    assert again.status_code == 409
    assert again.json()["code"] == "already_enrolled"


def test_join_class_with_bad_code(client, make_user, auth):
    student = make_user(UserRole.student, "25CE099")
    response = client.post("/classes/join", json={"join_code": "ZZZZZZ"}, headers=auth(student))
    assert response.status_code == 404
    assert response.json()["code"] == "invalid_join_code"


def test_teacher_cannot_join_class(client, make_user, auth, make_class):
    teacher = make_user(UserRole.teacher, "T001")
    cls = make_class()
    response = client.post("/classes/join", json={"join_code": cls.join_code}, headers=auth(teacher))
    assert response.status_code == 403


def test_class_detail_access_rules(client, make_user, auth, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    outsider_teacher = make_user(UserRole.teacher, "T002")
    member = make_user(UserRole.student, "25CE099")
    outsider = make_user(UserRole.student, "25CE100")
    cls = make_class(teacher=teacher)
    enroll(cls, member)

    assert client.get(f"/classes/{cls.id}", headers=auth(teacher)).status_code == 200
    assert client.get(f"/classes/{cls.id}", headers=auth(member)).status_code == 200
    for user in (outsider_teacher, outsider):
        response = client.get(f"/classes/{cls.id}", headers=auth(user))
        assert response.status_code == 404
        assert response.json()["code"] == "class_not_found"


def test_students_list_only_for_teacher_or_admin(client, make_user, auth, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    member = make_user(UserRole.student, "25CE099", name="An")
    cls = make_class(teacher=teacher)
    enroll(cls, member)

    response = client.get(f"/classes/{cls.id}/students", headers=auth(teacher))
    assert response.status_code == 200
    assert [s["student_id"] for s in response.json()] == ["25CE099"]
    assert client.get(f"/classes/{cls.id}/students", headers=auth(member)).status_code == 403
```

`backend/tests/test_sessions.py`:

```python
import pytest

from app.models import LectureSession, UserRole


@pytest.fixture()
def scene(make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    return teacher, student, cls


def test_teacher_starts_session_for_assigned_class(client, auth, scene):
    teacher, _, cls = scene
    response = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher))
    assert response.status_code == 201
    body = response.json()
    assert body["class_id"] == cls.id
    assert body["course_code"] == "PRM393"
    assert len(body["beacon_code"]) == 8
    assert body["is_active"] is True
    assert body["beacon_secret"] is None


def test_teacher_cannot_start_session_for_other_class(client, auth, make_user, make_class):
    teacher = make_user(UserRole.teacher, "T001")
    other = make_user(UserRole.teacher, "T002")
    cls = make_class(teacher=other)
    response = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher))
    assert response.status_code == 403
    assert response.json()["code"] == "forbidden"


def test_class_without_teacher_cannot_start(client, auth, make_user, make_class):
    teacher = make_user(UserRole.teacher, "T001")
    cls = make_class()
    assert client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).status_code == 403


def test_only_one_active_session_per_teacher(client, auth, scene, make_class):
    teacher, _, cls = scene
    second = make_class(teacher=teacher, class_code="SE1902")
    assert client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).status_code == 201
    response = client.post(f"/classes/{second.id}/sessions", headers=auth(teacher))
    assert response.status_code == 409
    assert response.json()["code"] == "session_already_active"


def test_student_sees_active_session_with_beacon_secret(client, auth, scene):
    teacher, student, cls = scene
    created = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    response = client.get("/sessions/active", headers=auth(student))
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == created["id"]
    assert len(body["beacon_secret"]) == 64


def test_student_outside_class_sees_no_active_session(client, auth, scene, make_user):
    teacher, _, cls = scene
    outsider = make_user(UserRole.student, "25CE100")
    client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher))
    response = client.get("/sessions/active", headers=auth(outsider))
    assert response.status_code == 404
    assert response.json()["code"] == "no_active_session"


def test_teacher_sees_own_active_session_without_secret(client, auth, scene):
    teacher, _, cls = scene
    client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher))
    body = client.get("/sessions/active", headers=auth(teacher)).json()
    assert body["beacon_secret"] is None


def test_admin_cannot_use_active_endpoint(client, auth, make_user):
    admin = make_user(UserRole.admin, "A001")
    assert client.get("/sessions/active", headers=auth(admin)).status_code == 403


def test_open_finalization(client, auth, scene):
    teacher, student, cls = scene
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    forbidden = client.post(f"/sessions/{session['id']}/open-finalization", headers=auth(student))
    assert forbidden.status_code == 403
    response = client.post(f"/sessions/{session['id']}/open-finalization", headers=auth(teacher))
    assert response.status_code == 200
    assert response.json()["finalization_open"] is True


def test_open_finalization_on_ended_session_conflicts(client, auth, scene):
    teacher, _, cls = scene
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    response = client.post(f"/sessions/{session['id']}/open-finalization", headers=auth(teacher))
    assert response.status_code == 409
    assert response.json()["code"] == "session_ended"


def test_end_session_is_idempotent(client, auth, scene, db):
    teacher, _, cls = scene
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    first = client.post(f"/sessions/{session['id']}/end", headers=auth(teacher)).json()
    second = client.post(f"/sessions/{session['id']}/end", headers=auth(teacher)).json()
    assert first["is_active"] is False
    assert first["finalization_open"] is False
    assert second["ends_at"] == first["ends_at"]
    assert db.get(LectureSession, session["id"]).is_active is False


def test_other_teacher_cannot_end_session(client, auth, scene, make_user):
    teacher, _, cls = scene
    other = make_user(UserRole.teacher, "T002")
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    response = client.post(f"/sessions/{session['id']}/end", headers=auth(other))
    assert response.status_code == 404
    assert response.json()["code"] == "session_not_found"


def test_session_history_newest_first(client, auth, scene):
    teacher, student, cls = scene
    first = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    client.post(f"/sessions/{first['id']}/end", headers=auth(teacher))
    second = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    history = client.get(f"/classes/{cls.id}/sessions", headers=auth(student)).json()
    assert {s["id"] for s in history} == {first["id"], second["id"]}
    assert all(s["beacon_secret"] is None for s in history)
```

- [ ] **Step 2: Chạy test để thấy thất bại**

Run: `.venv/bin/pytest tests/test_classes.py tests/test_sessions.py -q`
Expected: 404 trên `/classes/mine` v.v.

- [ ] **Step 3: Cài đặt access, schema, lecture service**

`backend/app/services/access.py`:

```python
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.models import ClassRoom, Enrollment, LectureSession, User, UserRole


def get_class_or_404(db: Session, class_id: str) -> ClassRoom:
    cls = db.get(ClassRoom, class_id)
    if cls is None:
        raise ApiError(404, "class_not_found", "Không tìm thấy lớp")
    return cls


def is_enrolled(db: Session, class_id: str, student_user_id: str) -> bool:
    return (
        db.scalar(
            select(Enrollment.id).where(
                Enrollment.class_id == class_id, Enrollment.student_user_id == student_user_id
            )
        )
        is not None
    )


def require_class_access(db: Session, user: User, cls: ClassRoom) -> None:
    if user.role == UserRole.admin:
        return
    if user.role == UserRole.teacher and cls.teacher_user_id == user.id:
        return
    if user.role == UserRole.student and is_enrolled(db, cls.id, user.id):
        return
    raise ApiError(404, "class_not_found", "Không tìm thấy lớp")


def get_session_or_404(db: Session, session_id: str) -> LectureSession:
    session = db.get(LectureSession, session_id)
    if session is None:
        raise ApiError(404, "session_not_found", "Không tìm thấy buổi học")
    return session


def require_session_teacher(user: User, session: LectureSession) -> None:
    if session.teacher_user_id != user.id:
        raise ApiError(404, "session_not_found", "Không tìm thấy buổi học")
```

`backend/app/schemas/sessions.py`:

```python
from datetime import datetime

from pydantic import BaseModel


class SessionOut(BaseModel):
    id: str
    class_id: str
    class_code: str
    course_code: str
    course_name: str
    teacher_user_id: str
    beacon_code: str
    starts_at: datetime
    ends_at: datetime | None
    is_active: bool
    finalization_open: bool
    beacon_secret: str | None = None
```

`backend/app/services/lecture.py`:

```python
from sqlalchemy.orm import Session

from app.models import ClassRoom, LectureSession
from app.schemas.sessions import SessionOut


def session_to_out(db: Session, session: LectureSession, beacon_secret: str | None = None) -> SessionOut:
    cls = db.get(ClassRoom, session.class_id)
    return SessionOut(
        id=session.id,
        class_id=session.class_id,
        class_code=cls.class_code,
        course_code=cls.course.code,
        course_name=cls.course.name,
        teacher_user_id=session.teacher_user_id,
        beacon_code=session.token[:8],
        starts_at=session.starts_at,
        ends_at=session.ends_at,
        is_active=session.is_active,
        finalization_open=session.finalization_open,
        beacon_secret=beacon_secret,
    )
```

- [ ] **Step 4: Cài đặt routers**

`backend/app/routers/classes.py`:

```python
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import get_current_user, require_roles
from app.models import ClassRoom, Course, Enrollment, User, UserRole
from app.schemas.classes import ClassOut, JoinClassIn, StudentOut
from app.services.academic import class_to_out
from app.services.access import get_class_or_404, is_enrolled, require_class_access

router = APIRouter(prefix="/classes", tags=["classes"])


@router.get("/mine", response_model=list[ClassOut])
def my_classes(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[ClassOut]:
    stmt = select(ClassRoom).join(Course, ClassRoom.course_id == Course.id)
    if user.role == UserRole.teacher:
        stmt = stmt.where(ClassRoom.teacher_user_id == user.id)
    elif user.role == UserRole.student:
        stmt = stmt.join(Enrollment, Enrollment.class_id == ClassRoom.id).where(
            Enrollment.student_user_id == user.id
        )
    stmt = stmt.order_by(Course.code, ClassRoom.class_code)
    show_code = user.role != UserRole.student
    return [class_to_out(db, cls, include_join_code=show_code) for cls in db.scalars(stmt)]


@router.post("/join", response_model=ClassOut)
def join_class(
    payload: JoinClassIn,
    db: Session = Depends(get_db),
    student: User = Depends(require_roles(UserRole.student)),
) -> ClassOut:
    code = payload.join_code.strip().upper()
    cls = db.scalar(select(ClassRoom).where(ClassRoom.join_code == code))
    if cls is None:
        raise ApiError(404, "invalid_join_code", "Mã lớp không hợp lệ")
    if is_enrolled(db, cls.id, student.id):
        raise ApiError(409, "already_enrolled", "Bạn đã ở trong lớp này")
    db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="join_code"))
    db.commit()
    return class_to_out(db, cls, include_join_code=False)


@router.get("/{class_id}", response_model=ClassOut)
def class_detail(
    class_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> ClassOut:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    return class_to_out(db, cls, include_join_code=user.role != UserRole.student)


@router.get("/{class_id}/students", response_model=list[StudentOut])
def class_students(
    class_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(UserRole.teacher, UserRole.admin)),
) -> list[User]:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    stmt = (
        select(User)
        .join(Enrollment, Enrollment.student_user_id == User.id)
        .where(Enrollment.class_id == cls.id)
        .order_by(User.student_id)
    )
    return list(db.scalars(stmt))
```

`backend/app/routers/sessions.py`:

```python
import secrets

from fastapi import APIRouter, Depends
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.core.clock import utcnow
from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import get_current_user, require_roles
from app.models import Enrollment, LectureSession, User, UserRole
from app.schemas.sessions import SessionOut
from app.services.access import (
    get_class_or_404,
    get_session_or_404,
    require_class_access,
    require_session_teacher,
)
from app.services.beacon import student_secret
from app.services.lecture import session_to_out

router = APIRouter(tags=["sessions"])


@router.post("/classes/{class_id}/sessions", response_model=SessionOut, status_code=201)
def start_session(
    class_id: str,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> SessionOut:
    cls = get_class_or_404(db, class_id)
    if cls.teacher_user_id != teacher.id:
        raise ApiError(403, "forbidden", "Bạn không được phân công lớp này")
    active = db.scalar(
        select(LectureSession.id).where(
            LectureSession.teacher_user_id == teacher.id, LectureSession.is_active.is_(True)
        )
    )
    if active is not None:
        raise ApiError(409, "session_already_active", "Bạn đang có một buổi học chưa kết thúc")
    session = LectureSession(
        class_id=cls.id, teacher_user_id=teacher.id, token=secrets.token_hex(8), starts_at=utcnow()
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session_to_out(db, session)


@router.get("/classes/{class_id}/sessions", response_model=list[SessionOut])
def class_sessions(
    class_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> list[SessionOut]:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    stmt = select(LectureSession).where(LectureSession.class_id == cls.id).order_by(desc(LectureSession.starts_at))
    return [session_to_out(db, s) for s in db.scalars(stmt)]


@router.post("/sessions/{session_id}/end", response_model=SessionOut)
def end_session(
    session_id: str,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> SessionOut:
    session = get_session_or_404(db, session_id)
    require_session_teacher(teacher, session)
    if session.is_active:
        session.is_active = False
        session.finalization_open = False
        session.ends_at = utcnow()
        db.commit()
    return session_to_out(db, session)


@router.post("/sessions/{session_id}/open-finalization", response_model=SessionOut)
def open_finalization(
    session_id: str,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> SessionOut:
    session = get_session_or_404(db, session_id)
    require_session_teacher(teacher, session)
    if not session.is_active:
        raise ApiError(409, "session_ended", "Buổi học đã kết thúc")
    session.finalization_open = True
    db.commit()
    return session_to_out(db, session)


@router.get("/sessions/active", response_model=SessionOut)
def active_session(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(UserRole.teacher, UserRole.student)),
) -> SessionOut:
    stmt = select(LectureSession).where(LectureSession.is_active.is_(True))
    if user.role == UserRole.teacher:
        stmt = stmt.where(LectureSession.teacher_user_id == user.id)
    else:
        stmt = stmt.join(Enrollment, Enrollment.class_id == LectureSession.class_id).where(
            Enrollment.student_user_id == user.id
        )
    session = db.scalar(stmt.order_by(desc(LectureSession.starts_at)))
    if session is None:
        raise ApiError(404, "no_active_session", "Hiện không có buổi học nào đang diễn ra")
    secret = student_secret(session.id, user.student_id) if user.role == UserRole.student else None
    return session_to_out(db, session, beacon_secret=secret)
```

Trong `backend/app/main.py` thêm import và `include_router` cho `classes` và `sessions` (đặt `classes` trước các route có path động khác; `/classes/mine` đã được khai báo trước `/classes/{class_id}` trong cùng router).

- [ ] **Step 5: Chạy test**

Run: `.venv/bin/pytest -q`
Expected: tất cả đạt.

- [ ] **Step 6: Commit**

```bash
git add backend/app backend/tests
git commit -m "feat(backend): class views and class-scoped lecture sessions"
```

---

### Task 8: Gửi detection theo lô có xác minh

**Files:**
- Create: `backend/app/schemas/detections.py`, `backend/app/routers/detections.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_detections.py`

**Interfaces:**
- Consumes: `student_secret`, `make_tag`, `bucket_of`, `verify_tag`, `to_naive_utc`, `utcnow`, `is_enrolled`, `normalize_id`.
- Produces: `POST /detections/batch` (teacher) nhận `{"detections": [{session_id, student_identifier, bucket, tag, rssi, observed_at}]}` trả `{"recorded": int, "rejected": int}`; hằng `MAX_OBSERVATION_AGE = timedelta(minutes=10)`.

- [ ] **Step 1: Viết test thất bại**

`backend/tests/test_detections.py`:

```python
from datetime import timedelta, timezone, datetime

import pytest
from sqlalchemy import func, select

from app.core.clock import utcnow
from app.models import Detection, LectureSession, UserRole
from app.services.beacon import bucket_of, make_tag, student_secret


@pytest.fixture()
def scenario(client, auth, make_user, make_class, enroll, db):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    # Buổi học đã bắt đầu 1 giờ trước để các quan sát trong quá khứ gần vẫn nằm trong buổi.
    row = db.get(LectureSession, session["id"])
    row.starts_at = utcnow() - timedelta(hours=1)
    db.commit()
    return teacher, student, session


def item(session, student_id, observed, rssi=-60, bucket=None, tag=None):
    bucket = bucket_of(observed) if bucket is None else bucket
    if tag is None:
        tag = make_tag(student_secret(session["id"], student_id), bucket)
    return {
        "session_id": session["id"],
        "student_identifier": student_id,
        "bucket": bucket,
        "tag": tag,
        "rssi": rssi,
        "observed_at": observed.isoformat() + "Z",
    }


def post(client, auth, teacher, *items):
    return client.post("/detections/batch", json={"detections": list(items)}, headers=auth(teacher))


def count(db):
    return db.scalar(select(func.count(Detection.id)))


def test_valid_detection_is_recorded(client, auth, scenario, db):
    teacher, _, session = scenario
    observed = utcnow() - timedelta(seconds=5)
    response = post(client, auth, teacher, item(session, "25CE099", observed))
    assert response.status_code == 200
    assert response.json() == {"recorded": 1, "rejected": 0}
    stored = db.scalar(select(Detection))
    assert stored.rssi == -60
    assert stored.detected_at == observed


def test_identifier_is_normalized(client, auth, scenario, db):
    teacher, _, session = scenario
    observed = utcnow()
    payload = item(session, "25CE099", observed)
    payload["student_identifier"] = " 25ce099 "
    assert post(client, auth, teacher, payload).json()["recorded"] == 1


def test_wrong_tag_is_rejected(client, auth, scenario, db):
    teacher, _, session = scenario
    response = post(client, auth, teacher, item(session, "25CE099", utcnow(), tag="00000000"))
    assert response.json() == {"recorded": 0, "rejected": 1}
    assert count(db) == 0


def test_bucket_one_away_accepted_two_away_rejected(client, auth, scenario):
    teacher, _, session = scenario
    observed = utcnow()
    base = bucket_of(observed)
    ok = item(session, "25CE099", observed, bucket=base + 1)
    bad = item(session, "25CE099", observed, bucket=base + 2)
    assert post(client, auth, teacher, ok, bad).json() == {"recorded": 1, "rejected": 1}


def test_student_outside_class_is_rejected(client, auth, scenario, make_user):
    teacher, _, session = scenario
    make_user(UserRole.student, "25CE100")
    response = post(client, auth, teacher, item(session, "25CE100", utcnow()))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_unknown_student_is_rejected(client, auth, scenario):
    teacher, _, session = scenario
    response = post(client, auth, teacher, item(session, "25CE777", utcnow()))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_other_teachers_session_is_rejected(client, auth, scenario, make_user):
    _, _, session = scenario
    other = make_user(UserRole.teacher, "T002")
    response = post(client, auth, other, item(session, "25CE099", utcnow()))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_ended_session_is_rejected(client, auth, scenario):
    teacher, _, session = scenario
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    response = post(client, auth, teacher, item(session, "25CE099", utcnow()))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_observation_older_than_ten_minutes_is_rejected(client, auth, scenario):
    teacher, _, session = scenario
    response = post(client, auth, teacher, item(session, "25CE099", utcnow() - timedelta(minutes=11)))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_observation_before_session_start_is_rejected(client, auth, scenario, db):
    teacher, _, session = scenario
    row = db.get(LectureSession, session["id"])
    row.starts_at = utcnow() - timedelta(minutes=2)
    db.commit()
    # 5 phút trước: còn trong giới hạn 10 phút nhưng trước giờ bắt đầu buổi học.
    response = post(client, auth, teacher, item(session, "25CE099", utcnow() - timedelta(minutes=5)))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_observation_in_the_future_is_rejected(client, auth, scenario):
    teacher, _, session = scenario
    response = post(client, auth, teacher, item(session, "25CE099", utcnow() + timedelta(minutes=5)))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_observed_at_with_utc_offset_is_converted(client, auth, scenario, db):
    teacher, _, session = scenario
    observed = utcnow() - timedelta(seconds=2)
    local = observed.replace(tzinfo=timezone.utc).astimezone(timezone(timedelta(hours=7)))
    payload = item(session, "25CE099", observed)
    payload["observed_at"] = local.isoformat()
    assert post(client, auth, teacher, payload).json()["recorded"] == 1
    assert abs((db.scalar(select(Detection)).detected_at - observed).total_seconds()) < 1


def test_student_cannot_post_batch(client, auth, scenario):
    _, student, session = scenario
    response = post(client, auth, student, item(session, "25CE099", utcnow()))
    assert response.status_code == 403


def test_mixed_batch_counts(client, auth, scenario):
    teacher, _, session = scenario
    good = item(session, "25CE099", utcnow())
    bad = item(session, "25CE099", utcnow(), tag="deadbeef")
    assert post(client, auth, teacher, good, bad, good).json() == {"recorded": 2, "rejected": 1}
```

- [ ] **Step 2: Chạy test để thấy thất bại**

Run: `.venv/bin/pytest tests/test_detections.py -q`
Expected: 404 trên `/detections/batch`.

- [ ] **Step 3: Cài đặt**

`backend/app/schemas/detections.py`:

```python
from datetime import datetime

from pydantic import BaseModel, Field


class DetectionItem(BaseModel):
    session_id: str
    student_identifier: str
    bucket: int
    tag: str = Field(min_length=8, max_length=8)
    rssi: int = Field(ge=-127, le=0)
    observed_at: datetime


class DetectionBatchIn(BaseModel):
    detections: list[DetectionItem] = Field(max_length=500)


class DetectionBatchOut(BaseModel):
    recorded: int
    rejected: int
```

`backend/app/routers/detections.py`:

```python
from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.clock import to_naive_utc, utcnow
from app.core.database import get_db
from app.core.security import require_roles
from app.core.validators import normalize_id
from app.models import Detection, LectureSession, User, UserRole
from app.schemas.detections import DetectionBatchIn, DetectionBatchOut
from app.services.access import is_enrolled
from app.services.beacon import student_secret, verify_tag

router = APIRouter(tags=["detections"])

MAX_OBSERVATION_AGE = timedelta(minutes=10)
MAX_FUTURE_SKEW = timedelta(minutes=1)


@router.post("/detections/batch", response_model=DetectionBatchOut)
def submit_batch(
    payload: DetectionBatchIn,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> DetectionBatchOut:
    now = utcnow()
    sessions: dict[str, LectureSession | None] = {}
    recorded = 0
    rejected = 0

    for entry in payload.detections:
        if entry.session_id not in sessions:
            sessions[entry.session_id] = db.get(LectureSession, entry.session_id)
        session = sessions[entry.session_id]
        if session is None or not session.is_active or session.teacher_user_id != teacher.id:
            rejected += 1
            continue

        observed = to_naive_utc(entry.observed_at)
        if observed < session.starts_at or observed > now + MAX_FUTURE_SKEW or now - observed > MAX_OBSERVATION_AGE:
            rejected += 1
            continue

        student_id = normalize_id(entry.student_identifier)
        student = db.scalar(
            select(User).where(User.student_id == student_id, User.role == UserRole.student)
        )
        if student is None or not is_enrolled(db, session.class_id, student.id):
            rejected += 1
            continue

        secret = student_secret(session.id, student_id)
        if not verify_tag(secret, entry.bucket, entry.tag, observed):
            rejected += 1
            continue

        db.add(
            Detection(
                session_id=session.id,
                student_user_id=student.id,
                rssi=entry.rssi,
                detected_at=observed,
            )
        )
        recorded += 1

    db.commit()
    return DetectionBatchOut(recorded=recorded, rejected=rejected)
```

Trong `backend/app/main.py` thêm import và `app.include_router(detections_router.router)`.

- [ ] **Step 4: Chạy test**

Run: `.venv/bin/pytest -q`
Expected: tất cả đạt.

- [ ] **Step 5: Commit**

```bash
git add backend/app backend/tests
git commit -m "feat(backend): verified batch detections with beacon tags"
```

---

### Task 9: Điểm danh: chốt, override, tạo bản ghi cả lớp khi kết thúc buổi

**Files:**
- Create: `backend/app/schemas/attendance.py`
- Create: `backend/app/services/attendance.py`
- Create: `backend/app/routers/attendance.py`
- Modify: `backend/app/routers/sessions.py` (hàm `end_session`), `backend/app/main.py`
- Test: `backend/tests/test_attendance_service.py`, `backend/tests/test_attendance_api.py`

**Interfaces:**
- Consumes: `presence_ratio`, `first_seen_at`, `PRESENT_THRESHOLD`, `local_date`, `utcnow`, models.
- Produces:
  - `services.attendance.RECENT_DETECTION_SECONDS = 90`
  - `resolve_status(ratio: float, finalized: bool, excused: bool) -> AttendanceStatus`
  - `finalize_session(db, session) -> None` (không commit)
  - `build_records(db, session) -> list[AttendanceRecordOut]`
  - `schemas.attendance`: `FinalizeIn(session_id)`, `FinalizeOut(session_id, finalized, finalized_at)`, `OverrideIn(student_user_id, status, reason)`, `AttendanceRecordOut`, `SessionAttendanceOut`
  - Endpoint: `POST /attendance/finalize` (student), `GET /sessions/{id}/attendance` (teacher chủ buổi hoặc admin), `POST /sessions/{id}/attendance/override` (teacher chủ buổi)

- [ ] **Step 1: Viết test thất bại cho service**

`backend/tests/test_attendance_service.py`:

```python
from datetime import date, datetime, timedelta

import pytest
from sqlalchemy import select

from app.models import (
    Attendance,
    AttendanceStatus,
    Detection,
    LeaveRequest,
    LeaveStatus,
    LectureSession,
    UserRole,
)
from app.services.attendance import finalize_session, resolve_status

START = datetime(2026, 10, 18, 3, 0, 0)  # 10:00 giờ địa phương


@pytest.fixture()
def world(make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    return teacher, student, cls


def ended_session(db, cls, teacher, starts=START, seconds=300):
    session = LectureSession(
        class_id=cls.id,
        teacher_user_id=teacher.id,
        token="abcdef0123456789",
        starts_at=starts,
        ends_at=starts + timedelta(seconds=seconds),
        is_active=False,
    )
    db.add(session)
    db.commit()
    return session


def detect(db, session, student, windows, rssi=-60):
    for window in windows:
        db.add(
            Detection(
                session_id=session.id,
                student_user_id=student.id,
                rssi=rssi,
                detected_at=session.starts_at + timedelta(seconds=window * 30 + 1),
            )
        )
    db.commit()


def finalize_row(db, session, student):
    db.add(Attendance(session_id=session.id, student_user_id=student.id, finalized=True))
    db.commit()


def row_of(db, session, student):
    return db.scalar(
        select(Attendance).where(
            Attendance.session_id == session.id, Attendance.student_user_id == student.id
        )
    )


@pytest.mark.parametrize(
    "ratio,finalized,excused,expected",
    [
        (0.6, True, False, AttendanceStatus.present),
        (0.59, True, False, AttendanceStatus.absent),
        (1.0, False, False, AttendanceStatus.absent),
        (0.0, False, True, AttendanceStatus.excused),
        (1.0, False, True, AttendanceStatus.excused),
        (1.0, True, True, AttendanceStatus.present),
    ],
)
def test_resolve_status(ratio, finalized, excused, expected):
    assert resolve_status(ratio, finalized, excused) == expected


def test_present_needs_ratio_and_finalization(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    detect(db, session, student, range(6))  # 6/10 = 0.6
    finalize_row(db, session, student)
    finalize_session(db, session)
    db.commit()
    row = row_of(db, session, student)
    assert row.presence_ratio == 0.6
    assert row.status == AttendanceStatus.present


def test_not_finalized_is_absent_even_with_full_presence(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    detect(db, session, student, range(10))
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.absent


def test_finalized_but_rarely_seen_is_absent(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    detect(db, session, student, range(5))  # 0.5
    finalize_row(db, session, student)
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.absent


def test_student_never_seen_still_gets_absent_row(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    finalize_session(db, session)
    db.commit()
    row = row_of(db, session, student)
    assert row.status == AttendanceStatus.absent
    assert row.presence_ratio == 0.0
    assert row.first_seen_at is None


def test_first_seen_is_recorded(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    detect(db, session, student, [2, 3])
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).first_seen_at == START + timedelta(seconds=61)


def test_approved_leave_makes_absence_excused(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    db.add(
        LeaveRequest(
            student_user_id=student.id,
            class_id=cls.id,
            date=date(2026, 10, 18),
            reason="Ốm",
            status=LeaveStatus.approved,
        )
    )
    db.commit()
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.excused


def test_pending_or_rejected_leave_does_not_excuse(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    for status in (LeaveStatus.pending, LeaveStatus.rejected):
        db.add(
            LeaveRequest(
                student_user_id=student.id,
                class_id=cls.id,
                date=date(2026, 10, 18),
                reason="Ốm",
                status=status,
            )
        )
    db.commit()
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.absent


def test_leave_date_uses_local_calendar_day(db, world):
    teacher, student, cls = world
    # 23:30 UTC ngày 17 = 06:30 giờ địa phương ngày 18.
    session = ended_session(db, cls, teacher, starts=datetime(2026, 10, 17, 23, 30, 0))
    db.add(
        LeaveRequest(
            student_user_id=student.id,
            class_id=cls.id,
            date=date(2026, 10, 18),
            reason="Ốm",
            status=LeaveStatus.approved,
        )
    )
    db.commit()
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.excused


def test_leave_for_another_class_does_not_excuse(db, world, make_class):
    teacher, student, cls = world
    other = make_class(teacher=teacher, class_code="SE1902")
    session = ended_session(db, cls, teacher)
    db.add(
        LeaveRequest(
            student_user_id=student.id,
            class_id=other.id,
            date=date(2026, 10, 18),
            reason="Ốm",
            status=LeaveStatus.approved,
        )
    )
    db.commit()
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.absent


def test_override_survives_finalize_session(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    db.add(
        Attendance(
            session_id=session.id,
            student_user_id=student.id,
            status=AttendanceStatus.present,
            overridden_by=teacher.id,
            override_reason="GV xác nhận",
        )
    )
    db.commit()
    finalize_session(db, session)
    db.commit()
    row = row_of(db, session, student)
    assert row.status == AttendanceStatus.present
    assert row.presence_ratio == 0.0


def test_finalize_session_only_creates_rows_for_enrolled_students(db, world, make_user):
    teacher, student, cls = world
    make_user(UserRole.student, "25CE100")
    session = ended_session(db, cls, teacher)
    finalize_session(db, session)
    db.commit()
    assert len(list(db.scalars(select(Attendance)))) == 1
```

- [ ] **Step 2: Viết test thất bại cho API**

`backend/tests/test_attendance_api.py`:

```python
from datetime import timedelta

import pytest
from sqlalchemy import select

from app.core.clock import utcnow
from app.models import Attendance, AttendanceStatus, Detection, LectureSession, UserRole


@pytest.fixture()
def live(client, auth, make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099", name="An")
    absent_student = make_user(UserRole.student, "25CE100", name="Binh")
    cls = make_class(teacher=teacher)
    enroll(cls, student, absent_student)
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    return teacher, student, absent_student, cls, session


def see(db, session, student, seconds_ago=10, rssi=-60):
    db.add(
        Detection(
            session_id=session["id"],
            student_user_id=student.id,
            rssi=rssi,
            detected_at=utcnow() - timedelta(seconds=seconds_ago),
        )
    )
    db.commit()


def open_finalization(client, auth, teacher, session):
    client.post(f"/sessions/{session['id']}/open-finalization", headers=auth(teacher))


def finalize(client, auth, student, session):
    return client.post("/attendance/finalize", json={"session_id": session["id"]}, headers=auth(student))


def test_finalize_requires_open_finalization(client, auth, live, db):
    _, student, _, _, session = live
    see(db, session, student)
    response = finalize(client, auth, student, session)
    assert response.status_code == 409
    assert response.json()["code"] == "finalization_not_open"


def test_finalize_requires_recent_detection(client, auth, live, db):
    teacher, student, _, _, session = live
    open_finalization(client, auth, teacher, session)
    response = finalize(client, auth, student, session)
    assert response.status_code == 409
    assert response.json()["code"] == "not_in_range"

    see(db, session, student, seconds_ago=120)
    assert finalize(client, auth, student, session).json()["code"] == "not_in_range"


def test_finalize_ignores_weak_recent_detection(client, auth, live, db):
    teacher, student, _, _, session = live
    open_finalization(client, auth, teacher, session)
    see(db, session, student, seconds_ago=5, rssi=-90)
    assert finalize(client, auth, student, session).json()["code"] == "not_in_range"


def test_finalize_success_marks_row(client, auth, live, db):
    teacher, student, _, _, session = live
    open_finalization(client, auth, teacher, session)
    see(db, session, student, seconds_ago=60)
    response = finalize(client, auth, student, session)
    assert response.status_code == 200
    assert response.json()["finalized"] is True
    row = db.scalar(select(Attendance).where(Attendance.student_user_id == student.id))
    assert row.finalized is True
    assert row.finalized_at is not None


def test_finalize_rejects_student_outside_class(client, auth, live, make_user, db):
    teacher, _, _, _, session = live
    outsider = make_user(UserRole.student, "25CE200")
    open_finalization(client, auth, teacher, session)
    response = finalize(client, auth, outsider, session)
    assert response.status_code == 404
    assert response.json()["code"] == "session_not_found"


def test_finalize_rejects_ended_session(client, auth, live, db):
    teacher, student, _, _, session = live
    open_finalization(client, auth, teacher, session)
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    response = finalize(client, auth, student, session)
    assert response.status_code == 409
    assert response.json()["code"] == "session_ended"


def test_teacher_cannot_finalize(client, auth, live):
    teacher, _, _, _, session = live
    assert finalize(client, auth, teacher, session).status_code == 403


def test_end_session_creates_rows_for_whole_class(client, auth, live, db):
    teacher, student, absent_student, _, session = live
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    rows = {r.student_user_id: r for r in db.scalars(select(Attendance))}
    assert set(rows) == {student.id, absent_student.id}
    assert all(r.status == AttendanceStatus.absent for r in rows.values())


def test_end_session_twice_does_not_recompute(client, auth, live, db):
    teacher, student, _, _, session = live
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    row = db.scalar(select(Attendance).where(Attendance.student_user_id == student.id))
    row.presence_ratio = 0.77
    db.commit()
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    db.expire_all()
    row = db.scalar(select(Attendance).where(Attendance.student_user_id == student.id))
    assert row.presence_ratio == 0.77


def test_live_attendance_lists_whole_class(client, auth, live, db):
    teacher, student, _, _, session = live
    see(db, session, student)
    response = client.get(f"/sessions/{session['id']}/attendance", headers=auth(teacher))
    assert response.status_code == 200
    body = response.json()
    assert body["total_students"] == 2
    assert body["present_students"] == 0
    by_id = {r["student_id"]: r for r in body["records"]}
    assert by_id["25CE099"]["detection_count"] == 1
    assert by_id["25CE100"]["detection_count"] == 0
    assert by_id["25CE100"]["status"] == "absent"


def test_attendance_list_rules(client, auth, live, make_user):
    teacher, student, _, _, session = live
    other = make_user(UserRole.teacher, "T002")
    admin = make_user(UserRole.admin, "A001")
    assert client.get(f"/sessions/{session['id']}/attendance", headers=auth(admin)).status_code == 200
    assert client.get(f"/sessions/{session['id']}/attendance", headers=auth(other)).status_code == 404
    assert client.get(f"/sessions/{session['id']}/attendance", headers=auth(student)).status_code == 403


def test_override_then_end_keeps_override(client, auth, live, db):
    teacher, student, _, _, session = live
    response = client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": student.id, "status": "present", "reason": "GV xác nhận có mặt"},
        headers=auth(teacher),
    )
    assert response.status_code == 200
    assert response.json()["status"] == "present"
    assert response.json()["overridden_by"] == teacher.id

    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    records = client.get(f"/sessions/{session['id']}/attendance", headers=auth(teacher)).json()["records"]
    mine = next(r for r in records if r["student_id"] == "25CE099")
    assert mine["status"] == "present"
    assert mine["overridden"] is True
    assert mine["override_reason"] == "GV xác nhận có mặt"


def test_student_finalize_after_override_does_not_change_status(client, auth, live, db):
    teacher, student, _, _, session = live
    client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": student.id, "status": "excused", "reason": "Có giấy phép"},
        headers=auth(teacher),
    )
    open_finalization(client, auth, teacher, session)
    see(db, session, student)
    assert finalize(client, auth, student, session).status_code == 200
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    row = db.scalar(select(Attendance).where(Attendance.student_user_id == student.id))
    db.refresh(row)
    assert row.status == AttendanceStatus.excused


def test_override_validation(client, auth, live, make_user):
    teacher, student, _, _, session = live
    short_reason = client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": student.id, "status": "present", "reason": "ok"},
        headers=auth(teacher),
    )
    assert short_reason.status_code == 422

    outsider = make_user(UserRole.student, "25CE200")
    not_in_class = client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": outsider.id, "status": "present", "reason": "Không thuộc lớp"},
        headers=auth(teacher),
    )
    assert not_in_class.status_code == 404
    assert not_in_class.json()["code"] == "student_not_in_class"


def test_student_cannot_override(client, auth, live):
    _, student, _, _, session = live
    response = client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": student.id, "status": "present", "reason": "Tự sửa điểm"},
        headers=auth(student),
    )
    assert response.status_code == 403
```

- [ ] **Step 3: Chạy test để thấy thất bại**

Run: `.venv/bin/pytest tests/test_attendance_service.py tests/test_attendance_api.py -q`
Expected: `ModuleNotFoundError: No module named 'app.services.attendance'`.

- [ ] **Step 4: Cài đặt service**

`backend/app/services/attendance.py`:

```python
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.clock import local_date, utcnow
from app.models import (
    Attendance,
    AttendanceStatus,
    ClassRoom,
    Detection,
    Enrollment,
    LeaveRequest,
    LeaveStatus,
    LectureSession,
    User,
)
from app.schemas.attendance import AttendanceRecordOut
from app.services.presence import PRESENT_THRESHOLD, Sample, first_seen_at, presence_ratio

RECENT_DETECTION_SECONDS = 90


def resolve_status(ratio: float, finalized: bool, excused: bool) -> AttendanceStatus:
    if ratio >= PRESENT_THRESHOLD and finalized:
        return AttendanceStatus.present
    if excused:
        return AttendanceStatus.excused
    return AttendanceStatus.absent


def enrolled_students(db: Session, class_id: str) -> list[User]:
    stmt = (
        select(User)
        .join(Enrollment, Enrollment.student_user_id == User.id)
        .where(Enrollment.class_id == class_id)
        .order_by(User.student_id)
    )
    return list(db.scalars(stmt))


def student_samples(db: Session, session_id: str, student_user_id: str) -> list[Sample]:
    rows = db.execute(
        select(Detection.detected_at, Detection.rssi).where(
            Detection.session_id == session_id, Detection.student_user_id == student_user_id
        )
    ).all()
    return [(moment, rssi) for moment, rssi in rows]


def has_approved_leave(db: Session, class_id: str, student_user_id: str, session: LectureSession) -> bool:
    found = db.scalar(
        select(LeaveRequest.id).where(
            LeaveRequest.class_id == class_id,
            LeaveRequest.student_user_id == student_user_id,
            LeaveRequest.status == LeaveStatus.approved,
            LeaveRequest.date == local_date(session.starts_at),
        )
    )
    return found is not None


def get_or_create_row(db: Session, session_id: str, student_user_id: str) -> Attendance:
    row = db.scalar(
        select(Attendance).where(
            Attendance.session_id == session_id, Attendance.student_user_id == student_user_id
        )
    )
    if row is None:
        row = Attendance(session_id=session_id, student_user_id=student_user_id)
        db.add(row)
        db.flush()
    return row


def finalize_session(db: Session, session: LectureSession) -> None:
    """Tính kết quả cuối buổi cho toàn bộ sinh viên của lớp. Người gọi chịu trách nhiệm commit."""
    cls = db.get(ClassRoom, session.class_id)
    end = session.ends_at or utcnow()
    for student in enrolled_students(db, cls.id):
        samples = student_samples(db, session.id, student.id)
        row = get_or_create_row(db, session.id, student.id)
        row.presence_ratio = presence_ratio(session.starts_at, end, samples, cls.rssi_threshold)
        row.first_seen_at = first_seen_at(samples, session.starts_at, end, cls.rssi_threshold)
        if row.overridden_by is None:
            excused = has_approved_leave(db, cls.id, student.id, session)
            row.status = resolve_status(row.presence_ratio, row.finalized, excused)
    db.flush()


def build_records(db: Session, session: LectureSession) -> list[AttendanceRecordOut]:
    cls = db.get(ClassRoom, session.class_id)
    end = session.ends_at or utcnow()
    rows = {
        row.student_user_id: row
        for row in db.scalars(select(Attendance).where(Attendance.session_id == session.id))
    }
    records: list[AttendanceRecordOut] = []
    for student in enrolled_students(db, cls.id):
        samples = student_samples(db, session.id, student.id)
        row = rows.get(student.id)
        settled = row is not None and not session.is_active

        if settled:
            ratio, first_seen = row.presence_ratio, row.first_seen_at
        else:
            ratio = presence_ratio(session.starts_at, end, samples, cls.rssi_threshold)
            first_seen = first_seen_at(samples, session.starts_at, end, cls.rssi_threshold)

        if row is not None and (row.overridden_by is not None or settled):
            status = row.status
        else:
            excused = has_approved_leave(db, cls.id, student.id, session)
            status = resolve_status(ratio, bool(row and row.finalized), excused)

        records.append(
            AttendanceRecordOut(
                student_user_id=student.id,
                student_id=student.student_id,
                student_name=student.full_name,
                detection_count=len(samples),
                presence_ratio=ratio,
                status=status,
                finalized=bool(row and row.finalized),
                first_seen_at=first_seen,
                overridden=bool(row and row.overridden_by is not None),
                override_reason=row.override_reason if row else None,
            )
        )
    return records
```

- [ ] **Step 5: Cài đặt schemas và router**

`backend/app/schemas/attendance.py`:

```python
from datetime import datetime

from pydantic import BaseModel, Field

from app.models import AttendanceStatus


class FinalizeIn(BaseModel):
    session_id: str


class FinalizeOut(BaseModel):
    session_id: str
    finalized: bool
    finalized_at: datetime | None


class OverrideIn(BaseModel):
    student_user_id: str
    status: AttendanceStatus
    reason: str = Field(min_length=3, max_length=255)


class OverrideOut(BaseModel):
    student_user_id: str
    status: AttendanceStatus
    overridden_by: str
    overridden_at: datetime
    override_reason: str


class AttendanceRecordOut(BaseModel):
    student_user_id: str
    student_id: str | None
    student_name: str
    detection_count: int
    presence_ratio: float
    status: AttendanceStatus
    finalized: bool
    first_seen_at: datetime | None
    overridden: bool
    override_reason: str | None


class SessionAttendanceOut(BaseModel):
    session_id: str
    class_id: str
    total_students: int
    present_students: int
    records: list[AttendanceRecordOut]
```

`backend/app/routers/attendance.py`:

```python
from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.clock import utcnow
from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import require_roles
from app.models import AttendanceStatus, ClassRoom, Detection, User, UserRole
from app.schemas.attendance import (
    FinalizeIn,
    FinalizeOut,
    OverrideIn,
    OverrideOut,
    SessionAttendanceOut,
)
from app.services.access import get_session_or_404, is_enrolled, require_session_teacher
from app.services.attendance import (
    RECENT_DETECTION_SECONDS,
    build_records,
    get_or_create_row,
)

router = APIRouter(tags=["attendance"])


@router.post("/attendance/finalize", response_model=FinalizeOut)
def finalize_attendance(
    payload: FinalizeIn,
    db: Session = Depends(get_db),
    student: User = Depends(require_roles(UserRole.student)),
) -> FinalizeOut:
    session = get_session_or_404(db, payload.session_id)
    if not is_enrolled(db, session.class_id, student.id):
        raise ApiError(404, "session_not_found", "Không tìm thấy buổi học")
    if not session.is_active:
        raise ApiError(409, "session_ended", "Buổi học đã kết thúc")
    if not session.finalization_open:
        raise ApiError(409, "finalization_not_open", "Giảng viên chưa mở chốt điểm danh")

    cls = db.get(ClassRoom, session.class_id)
    cutoff = utcnow() - timedelta(seconds=RECENT_DETECTION_SECONDS)
    recent = db.scalar(
        select(func.count(Detection.id)).where(
            Detection.session_id == session.id,
            Detection.student_user_id == student.id,
            Detection.detected_at >= cutoff,
            Detection.rssi > cls.rssi_threshold,
        )
    )
    if not recent:
        raise ApiError(409, "not_in_range", "Chưa phát hiện bạn trong lớp, hãy lại gần giảng viên")

    row = get_or_create_row(db, session.id, student.id)
    row.finalized = True
    row.finalized_at = utcnow()
    db.commit()
    return FinalizeOut(session_id=session.id, finalized=True, finalized_at=row.finalized_at)


@router.get("/sessions/{session_id}/attendance", response_model=SessionAttendanceOut)
def session_attendance(
    session_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(UserRole.teacher, UserRole.admin)),
) -> SessionAttendanceOut:
    session = get_session_or_404(db, session_id)
    if user.role == UserRole.teacher:
        require_session_teacher(user, session)
    records = build_records(db, session)
    present = sum(1 for record in records if record.status == AttendanceStatus.present)
    return SessionAttendanceOut(
        session_id=session.id,
        class_id=session.class_id,
        total_students=len(records),
        present_students=present,
        records=records,
    )


@router.post("/sessions/{session_id}/attendance/override", response_model=OverrideOut)
def override_attendance(
    session_id: str,
    payload: OverrideIn,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> OverrideOut:
    session = get_session_or_404(db, session_id)
    require_session_teacher(teacher, session)
    if not is_enrolled(db, session.class_id, payload.student_user_id):
        raise ApiError(404, "student_not_in_class", "Sinh viên không thuộc lớp này")

    row = get_or_create_row(db, session.id, payload.student_user_id)
    row.status = payload.status
    row.overridden_by = teacher.id
    row.overridden_at = utcnow()
    row.override_reason = payload.reason.strip()
    db.commit()
    return OverrideOut(
        student_user_id=row.student_user_id,
        status=row.status,
        overridden_by=teacher.id,
        overridden_at=row.overridden_at,
        override_reason=row.override_reason,
    )
```

- [ ] **Step 6: Nối `finalize_session` vào kết thúc buổi**

Trong `backend/app/routers/sessions.py`, thêm import `from app.services.attendance import finalize_session` và sửa `end_session`:

Old:
```python
        session.ends_at = utcnow()
        db.commit()
```
New:
```python
        session.ends_at = utcnow()
        finalize_session(db, session)
        db.commit()
```

Trong `backend/app/main.py` thêm import và `app.include_router(attendance_router.router)`.

- [ ] **Step 7: Chạy test**

Run: `.venv/bin/pytest -q`
Expected: tất cả đạt (không còn test nào đỏ).

- [ ] **Step 8: Commit**

```bash
git add backend/app backend/tests
git commit -m "feat(backend): attendance finalize, override and per-class settlement"
```

---

### Task 10: Seed dữ liệu demo, tài liệu chạy và kiểm tra tổng

**Files:**
- Create: `backend/app/services/seed.py`
- Modify: `backend/scripts/seed_demo.py`, `backend/README.md`, `backend/.env.example`
- Test: `backend/tests/test_seed.py`

**Interfaces:**
- Consumes: models, `hash_password`, `new_join_code`.
- Produces: `services.seed.seed(db) -> dict[str, str]` (idempotent; trả `{"join_code": ...}`); tài khoản demo: admin `A001`, GV `T001`, SV `25CE099`, `25CE100`, `D26CE045`, mật khẩu `Pass@123`; môn `PRM393`, lớp `SE1901` học kỳ `FA26` gán cho `T001`, cả 3 SV đã ghi danh.

- [ ] **Step 1: Viết test thất bại**

`backend/tests/test_seed.py`:

```python
from sqlalchemy import func, select

from app.models import ClassRoom, Enrollment, User
from app.services.seed import seed


def test_seed_creates_demo_data(db):
    result = seed(db)
    assert db.scalar(select(func.count(User.id))) == 5
    assert db.scalar(select(func.count(ClassRoom.id))) == 1
    assert db.scalar(select(func.count(Enrollment.id))) == 3
    cls = db.scalar(select(ClassRoom))
    assert result["join_code"] == cls.join_code
    assert cls.teacher.teacher_id == "T001"


def test_seed_is_idempotent(db):
    first = seed(db)
    second = seed(db)
    assert first == second
    assert db.scalar(select(func.count(User.id))) == 5
    assert db.scalar(select(func.count(Enrollment.id))) == 3


def test_seeded_accounts_can_login(client, db):
    seed(db)
    for ident in ("A001", "T001", "25CE099"):
        response = client.post("/auth/login", json={"identifier": ident, "password": "Pass@123"})
        assert response.status_code == 200
        assert response.json()["must_change_password"] is False
```

- [ ] **Step 2: Chạy test để thấy thất bại**

Run: `.venv/bin/pytest tests/test_seed.py -q`
Expected: `ModuleNotFoundError: No module named 'app.services.seed'`.

- [ ] **Step 3: Cài đặt seed**

`backend/app/services/seed.py`:

```python
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models import ClassRoom, Course, Enrollment, User, UserRole
from app.services.academic import new_join_code

DEMO_PASSWORD = "Pass@123"


def _ensure_user(db: Session, role: UserRole, ident: str, name: str) -> User:
    column = User.student_id if role == UserRole.student else User.teacher_id
    user = db.scalar(select(User).where(column == ident))
    if user is None:
        ids = {"student_id": ident} if role == UserRole.student else {"teacher_id": ident}
        user = User(full_name=name, role=role, password_hash=hash_password(DEMO_PASSWORD), **ids)
        db.add(user)
        db.flush()
    return user


def seed(db: Session) -> dict[str, str]:
    _ensure_user(db, UserRole.admin, "A001", "Quản trị viên")
    teacher = _ensure_user(db, UserRole.teacher, "T001", "Giảng viên Demo")
    students = [
        _ensure_user(db, UserRole.student, "25CE099", "Sinh viên Một"),
        _ensure_user(db, UserRole.student, "25CE100", "Sinh viên Hai"),
        _ensure_user(db, UserRole.student, "D26CE045", "Sinh viên Ba"),
    ]

    course = db.scalar(select(Course).where(Course.code == "PRM393"))
    if course is None:
        course = Course(code="PRM393", name="Lập trình di động", credits=3)
        db.add(course)
        db.flush()

    cls = db.scalar(
        select(ClassRoom).where(
            ClassRoom.course_id == course.id,
            ClassRoom.class_code == "SE1901",
            ClassRoom.semester == "FA26",
        )
    )
    if cls is None:
        cls = ClassRoom(
            course_id=course.id,
            class_code="SE1901",
            semester="FA26",
            teacher_user_id=teacher.id,
            join_code=new_join_code(db),
        )
        db.add(cls)
        db.flush()

    for student in students:
        exists = db.scalar(
            select(Enrollment.id).where(
                Enrollment.class_id == cls.id, Enrollment.student_user_id == student.id
            )
        )
        if exists is None:
            db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="import"))

    db.commit()
    return {"join_code": cls.join_code}
```

`backend/scripts/seed_demo.py` (thay toàn bộ):

```python
import os
import sys

ROOT = os.path.dirname(os.path.dirname(__file__))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from app.core.database import SessionLocal
from app.services.seed import seed


def main() -> None:
    db = SessionLocal()
    try:
        result = seed(db)
        print("Seed xong: admin A001, giảng viên T001, sinh viên 25CE099/25CE100/D26CE045")
        print(f"Mã lớp SE1901: {result['join_code']}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Cập nhật `.env.example` và README backend**

Thêm vào `backend/.env.example`:

```text
BEACON_SERVER_KEY=replace-this-beacon-key
LOCAL_UTC_OFFSET_HOURS=7
```

Thay phần "Chạy cục bộ" và "API chính" trong `backend/README.md` bằng:

````markdown
## Chạy cục bộ (Linux/macOS)

```bash
cd backend
docker compose up -d
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
alembic upgrade head
python scripts/seed_demo.py
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Swagger: `http://127.0.0.1:8000/docs`

## Kiểm thử

```bash
pytest -q
```

## Tài khoản demo (mật khẩu `Pass@123`)

- Admin: `A001` · Giảng viên: `T001` · Sinh viên: `25CE099`, `25CE100`, `D26CE045`

## Thay đổi schema

Tạo migration bằng `alembic revision --autogenerate -m "mô tả"` rồi `alembic upgrade head`.
Không còn tự `ALTER TABLE` khi khởi động.
````

- [ ] **Step 5: Chạy toàn bộ test**

Run: `.venv/bin/pytest -q`
Expected: tất cả đạt, ghi lại tổng số test.

- [ ] **Step 6: Kiểm tra thực tế với PostgreSQL**

```bash
cd backend
docker compose up -d
.venv/bin/alembic upgrade head
.venv/bin/python scripts/seed_demo.py
(.venv/bin/uvicorn app.main:app --port 8000 &) ; sleep 3
curl -s localhost:8000/health
TOKEN=$(curl -s -X POST localhost:8000/auth/login -H 'content-type: application/json' -d '{"identifier":"A001","password":"Pass@123"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
curl -s localhost:8000/admin/classes -H "Authorization: Bearer $TOKEN"
pkill -f "uvicorn app.main" ; true
```
Expected: `{"status":"ok"}` và danh sách một lớp `SE1901` do `T001` dạy, `student_count` bằng 3. Nếu Docker không chạy được, ghi rõ bước này chưa kiểm chứng.

- [ ] **Step 7: Commit**

```bash
cd /home/kiet/code/PRM/ble_attendance_mobile
git add backend/app/services/seed.py backend/scripts backend/README.md backend/.env.example backend/tests/test_seed.py
git commit -m "feat(backend): idempotent demo seed and updated backend docs"
```

---

## Self-Review (đã thực hiện khi viết plan)

**Phủ spec (mục 2, 3, 4, 5, 6 của spec):**
- Vai trò và phân quyền (mục 2): Task 3 (`require_roles`, bỏ tự đăng ký GV), Task 6 (admin), Task 7 (lớp/buổi theo role).
- Mô hình dữ liệu (mục 3): Task 2 (đủ 9 bảng, gồm `leave_requests` và `notifications` cho Plan 2).
- Quy tắc điểm danh (mục 4): Task 4 (ratio, trung vị, `first_seen_at`), Task 9 (trạng thái, override thắng, chốt cần detection 90 giây, kết thúc buổi tạo bản ghi cả lớp, `excused`).
- Beacon HMAC và `observed_at` (mục 5): Task 5, Task 8; `beacon_secret` trả ở `GET /sessions/active` (Task 7).
- API mục 6.2 trong phạm vi Plan 1: auth, admin (môn, lớp, GV, assign, reset), classes, sessions, detections, attendance finalize/list/override.
- **Chưa thuộc Plan 1 (chuyển sang Plan 2):** import (mục 6.3), thống kê SV (`/me/attendance`), báo cáo/Excel, xin phép, thông báo.

**Quét placeholder:** không có "TBD/TODO"; mọi bước code đều có nội dung đầy đủ.

**Nhất quán kiểu:** `student_secret(session_id, student_id)`, `make_tag(secret, bucket)`, `verify_tag(secret, bucket, tag, observed_at)`, `presence_ratio/first_seen_at(…, rssi_threshold)`, `finalize_session(db, session)`, `build_records(db, session)`, `get_or_create_row(db, session_id, student_user_id)`, `is_enrolled(db, class_id, student_user_id)`, `require_session_teacher(user, session)` được dùng thống nhất ở các task sau.

**Điểm sai khác có chủ đích so với spec:** `RECENT_DETECTION_SECONDS = 90` (spec đã được cập nhật tương ứng); `TokenResponse` thêm `must_change_password`.
