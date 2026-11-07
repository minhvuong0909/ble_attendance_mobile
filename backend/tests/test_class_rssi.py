from app.models import UserRole


def patch(client, cls, headers, value):
    return client.patch(f"/classes/{cls.id}/rssi", json={"rssi_threshold": value}, headers=headers)


def test_teacher_changes_own_class_threshold(client, db, make_user, make_class, auth):
    teacher = make_user(UserRole.teacher, "T001")
    cls = make_class(teacher=teacher)
    response = patch(client, cls, auth(teacher), -85)
    assert response.status_code == 200
    assert response.json()["rssi_threshold"] == -85
    db.refresh(cls)
    assert cls.rssi_threshold == -85
    detail = client.get(f"/classes/{cls.id}", headers=auth(teacher))
    assert detail.json()["rssi_threshold"] == -85


def test_threshold_must_stay_in_range(client, make_user, make_class, auth):
    teacher = make_user(UserRole.teacher, "T001")
    cls = make_class(teacher=teacher)
    for bad in (-101, -29, 0):
        assert patch(client, cls, auth(teacher), bad).status_code == 422
    for ok in (-100, -30):
        assert patch(client, cls, auth(teacher), ok).status_code == 200


def test_other_teacher_cannot_change(client, db, make_user, make_class, auth):
    owner = make_user(UserRole.teacher, "T001")
    other = make_user(UserRole.teacher, "T002")
    cls = make_class(teacher=owner)
    response = patch(client, cls, auth(other), -90)
    assert response.status_code == 403
    db.refresh(cls)
    assert cls.rssi_threshold == -75


def test_student_cannot_change(client, make_user, make_class, enroll, auth):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    assert patch(client, cls, auth(student), -90).status_code == 403


def test_unknown_class_is_404(client, make_user, auth):
    teacher = make_user(UserRole.teacher, "T001")
    response = client.patch("/classes/nope/rssi", json={"rssi_threshold": -80}, headers=auth(teacher))
    assert response.status_code == 404


def test_requires_login(client, make_user, make_class):
    teacher = make_user(UserRole.teacher, "T001")
    cls = make_class(teacher=teacher)
    assert client.patch(f"/classes/{cls.id}/rssi", json={"rssi_threshold": -80}).status_code == 401


def test_new_session_exposes_updated_threshold(client, make_user, make_class, enroll, auth):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    patch(client, cls, auth(teacher), -88)
    client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher))
    active = client.get("/sessions/active", headers=auth(student))
    assert active.json()["rssi_threshold"] == -88
