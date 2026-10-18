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
