from sqlalchemy import func, select

from app.models import ClassRoom, Course, Enrollment, User
from app.services.seed import seed


def test_seed_creates_demo_data(db):
    seed(db)
    assert db.scalar(select(func.count(User.id))) == 7
    assert db.scalar(select(func.count(Course.id))) == 4
    assert db.scalar(select(func.count(ClassRoom.id))) == 4
    assert db.scalar(select(func.count(Enrollment.id))) == 3
    cls = db.scalar(select(ClassRoom).where(ClassRoom.class_code == "SE1901"))
    assert cls.teacher.teacher_id == "GV1"


def test_seed_adds_the_timetable_courses_with_their_classes(db):
    seed(db)
    rows = db.execute(
        select(Course.code, ClassRoom.class_code, User.teacher_id)
        .join(ClassRoom, ClassRoom.course_id == Course.id)
        .join(User, User.id == ClassRoom.teacher_user_id)
        .order_by(Course.code, ClassRoom.class_code)
    ).all()
    assert rows == [
        ("EXE201", "SE1919", "GV2"),
        ("MLN131", "Half2_EL1902", "GV3"),
        ("PRM393", "SE1901", "GV1"),
        ("PRN232", "SE1918", "GV2"),
    ]


def test_seed_is_idempotent(db):
    seed(db)
    seed(db)
    assert db.scalar(select(func.count(User.id))) == 7
    assert db.scalar(select(func.count(ClassRoom.id))) == 4
    assert db.scalar(select(func.count(Enrollment.id))) == 3


def test_seeded_accounts_can_login(client, db):
    seed(db)
    for ident in ("admin", "gv1", "gv2", "gv3", "sv1", "SV3"):
        response = client.post(
            "/auth/login",
            json={"identifier": ident, "password": "123456", "device_id": "dev-test-1"},
        )
        assert response.status_code == 200
        assert response.json()["must_change_password"] is False
