import os

os.environ["DATABASE_URL_OVERRIDE"] = "sqlite://"
os.environ["JWT_SECRET"] = "test-secret"
os.environ["BEACON_SERVER_KEY"] = "key"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models import ClassRoom, Course, Enrollment, User, UserRole
from app import models as _models  # noqa: F401  (đăng ký bảng vào Base.metadata)


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


@pytest.fixture(autouse=True)
def _reset_login_limits():
    from app.core import ratelimit

    ratelimit.login_by_identifier.reset()
    ratelimit.login_by_ip.reset()
    yield
