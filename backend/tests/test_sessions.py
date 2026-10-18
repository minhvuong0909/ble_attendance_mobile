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
