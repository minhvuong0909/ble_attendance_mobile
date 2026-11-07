import pytest
from sqlalchemy import event

from app.core.config import Settings
from app.core.ratelimit import FailureLimiter
from app.models import UserRole


def test_must_change_password_blocks_other_endpoints(client, make_user, auth):
    user = make_user(UserRole.teacher, "T777", must_change=True)
    headers = auth(user)
    assert client.get("/auth/me", headers=headers).status_code == 200
    blocked = client.get("/classes/mine", headers=headers)
    assert blocked.status_code == 403
    assert blocked.json()["code"] == "password_change_required"
    changed = client.post(
        "/auth/change-password", json={"old_password": "Pass@123", "new_password": "NewPass@1"}, headers=headers
    )
    assert changed.status_code == 200
    assert client.get("/classes/mine", headers=headers).status_code == 200


def test_login_locks_after_repeated_failures(client, make_user):
    make_user(UserRole.student, "25CE001")
    for _ in range(5):
        assert client.post("/auth/login", json={"identifier": "25CE001", "password": "bad"}).status_code == 401
    locked = client.post("/auth/login", json={"identifier": "25CE001", "password": "Pass@123"})
    assert locked.status_code == 429
    assert locked.json()["code"] == "too_many_attempts"


def test_successful_login_clears_failures(client, make_user):
    make_user(UserRole.student, "25CE002")
    for _ in range(4):
        client.post("/auth/login", json={"identifier": "25CE002", "password": "bad"})
    assert client.post("/auth/login", json={"identifier": "25CE002", "password": "Pass@123", "device_id": "dev-test-1"}).status_code == 200
    for _ in range(4):
        assert client.post("/auth/login", json={"identifier": "25CE002", "password": "bad"}).status_code == 401


def test_limiter_window_expires():
    clock = [0.0]
    limiter = FailureLimiter(2, 10, now=lambda: clock[0])
    limiter.record("k")
    limiter.record("k")
    assert limiter.blocked("k")
    clock[0] = 11
    assert not limiter.blocked("k")


def test_weak_secrets_rejected_outside_dev():
    with pytest.raises(ValueError):
        Settings(app_env="prod", _env_file=None)
    ok = Settings(app_env="prod", jwt_secret="x" * 32, beacon_server_key="y" * 32, _env_file=None)
    assert ok.app_env == "prod"
    Settings(app_env="dev", _env_file=None)


def test_finalize_session_query_count_does_not_grow_with_class_size(client, db, make_user, make_class, enroll, auth):
    from app.core.clock import utcnow
    from app.models import Detection, LectureSession
    from app.services.attendance import build_records, finalize_session

    teacher = make_user(UserRole.teacher, "T800")
    cls = make_class(teacher)

    def run(count: int) -> int:
        students = [make_user(UserRole.student, f"{count:02d}CE{i:03d}") for i in range(count)]
        enroll(cls, *students)
        session = LectureSession(class_id=cls.id, teacher_user_id=teacher.id, token="t" * 16, starts_at=utcnow())
        db.add(session)
        db.commit()
        for s in students:
            db.add(Detection(session_id=session.id, student_user_id=s.id, rssi=-50, detected_at=utcnow()))
        db.commit()
        counter = {"n": 0}

        def count_query(_conn, _cursor, statement, *_args):
            if statement.lstrip().upper().startswith("SELECT"):
                counter["n"] += 1

        event.listen(db.get_bind(), "before_cursor_execute", count_query)
        try:
            build_records(db, session)
            finalize_session(db, session)
        finally:
            event.remove(db.get_bind(), "before_cursor_execute", count_query)
        return counter["n"]

    small = run(3)
    large = run(20)
    assert large <= small + 2  # số SELECT không tăng theo số sinh viên


def test_class_list_select_count_constant(client, db, make_user, make_class, enroll, auth):
    admin = make_user(UserRole.admin, "A900")
    teacher = make_user(UserRole.teacher, "T900")
    student = make_user(UserRole.student, "25CE900")

    def selects() -> int:
        counter = {"n": 0}

        def count_query(_conn, _cursor, statement, *_args):
            if statement.lstrip().upper().startswith("SELECT"):
                counter["n"] += 1

        event.listen(db.get_bind(), "before_cursor_execute", count_query)
        try:
            response = client.get("/admin/classes", headers=auth(admin))
            assert response.status_code == 200
        finally:
            event.remove(db.get_bind(), "before_cursor_execute", count_query)
        return counter["n"]

    for i in range(2):
        enroll(make_class(teacher, course_code=f"C{i}0", class_code=f"L{i}"), student)
    few = selects()
    for i in range(2, 8):
        enroll(make_class(teacher, course_code=f"C{i}0", class_code=f"L{i}"), student)
    many = selects()
    assert many == few
    rows = client.get("/admin/classes", headers=auth(admin)).json()
    assert len(rows) == 8 and all(r["student_count"] == 1 for r in rows)
