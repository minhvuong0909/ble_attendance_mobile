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


def test_students_cannot_join_a_class_by_themselves(client, db, make_user, auth, make_class):
    """Sinh viên chỉ được admin xếp lớp (nhập danh sách), không tự tham gia bằng mã."""
    student = make_user(UserRole.student, "25CE099")
    cls = make_class()
    for code in (cls.join_code, cls.join_code.lower(), "ZZZZZZ"):
        response = client.post("/classes/join", json={"join_code": code}, headers=auth(student))
        assert response.status_code in (404, 405)
    assert client.get("/classes/mine", headers=auth(student)).json() == []


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
