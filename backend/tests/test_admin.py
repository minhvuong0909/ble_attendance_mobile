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
    login = client.post("/auth/login", json={"identifier": "25CE099", "password": "25CE099", "device_id": "dev-test-1"})
    assert login.status_code == 200
    assert login.json()["must_change_password"] is True


def test_update_class_rejects_duplicate_code_and_semester(client, admin, auth, make_class):
    make_class(class_code="SE1901", semester="FA26")
    other = make_class(class_code="SE1902", semester="FA26")
    response = client.patch(
        f"/admin/classes/{other.id}", json={"class_code": "se1901"}, headers=auth(admin)
    )
    assert response.status_code == 409
    assert response.json()["code"] == "class_exists"
    renamed = client.patch(
        f"/admin/classes/{other.id}", json={"class_code": "SE1901", "semester": "SP27"}, headers=auth(admin)
    )
    assert renamed.status_code == 200
    same = client.patch(f"/admin/classes/{other.id}", json={"class_code": "SE1901"}, headers=auth(admin))
    assert same.status_code == 200
