from sqlalchemy import select

from app.models import DeviceChangeRequest, Notification, User, UserRole


def login(client, ident="25CE099", device_id="dev-A", password="Pass@123"):
    body = {"identifier": ident, "password": password}
    if device_id is not None:
        body["device_id"] = device_id
    return client.post("/auth/login", json=body)


def request_change(client, ident="25CE099", device_id="dev-B", reason="Đổi điện thoại mới", password="Pass@123"):
    return client.post(
        "/auth/device-change-requests",
        json={"identifier": ident, "password": password, "device_id": device_id, "reason": reason},
    )


def test_first_login_binds_device(client, db, make_user):
    make_user(UserRole.student, "25CE099")
    assert login(client).status_code == 200
    user = db.scalar(select(User).where(User.student_id == "25CE099"))
    assert user.device_id == "dev-A"


def test_same_device_can_log_in_again(client, make_user):
    make_user(UserRole.student, "25CE099")
    assert login(client).status_code == 200
    assert login(client).status_code == 200


def test_other_device_is_rejected(client, make_user):
    make_user(UserRole.student, "25CE099")
    login(client, device_id="dev-A")
    response = login(client, device_id="dev-B")
    assert response.status_code == 403
    assert response.json()["code"] == "device_mismatch"


def test_student_login_requires_device_id(client, make_user):
    make_user(UserRole.student, "25CE099")
    response = login(client, device_id=None)
    assert response.status_code == 422
    assert response.json()["code"] == "device_required"


def test_wrong_password_does_not_bind_device(client, db, make_user):
    make_user(UserRole.student, "25CE099")
    assert login(client, password="sai-mat-khau").status_code == 401
    user = db.scalar(select(User).where(User.student_id == "25CE099"))
    assert user.device_id is None


def test_teacher_and_admin_are_not_bound(client, db, make_user):
    make_user(UserRole.teacher, "T001")
    make_user(UserRole.admin, "A001")
    assert login(client, "T001", device_id=None).status_code == 200
    assert login(client, "T001", device_id="dev-A").status_code == 200
    assert login(client, "T001", device_id="dev-B").status_code == 200
    assert login(client, "A001", device_id=None).status_code == 200
    assert db.scalar(select(User).where(User.teacher_id == "T001")).device_id is None


def test_two_students_may_share_one_device(client, make_user):
    make_user(UserRole.student, "25CE099")
    make_user(UserRole.student, "25CE100")
    assert login(client, "25CE099", "dev-A").status_code == 200
    assert login(client, "25CE100", "dev-A").status_code == 200


def test_request_creates_pending_row(client, db, make_user):
    make_user(UserRole.student, "25CE099")
    login(client, device_id="dev-A")
    response = request_change(client)
    assert response.status_code == 201
    assert response.json()["status"] == "pending"
    row = db.scalar(select(DeviceChangeRequest))
    assert row.new_device_id == "dev-B"
    assert row.reason == "Đổi điện thoại mới"


def test_request_requires_valid_password(client, make_user):
    make_user(UserRole.student, "25CE099")
    login(client, device_id="dev-A")
    response = request_change(client, password="sai-mat-khau")
    assert response.status_code == 401
    assert response.json()["code"] == "invalid_credentials"


def test_request_rejected_when_same_device_or_unbound(client, make_user):
    make_user(UserRole.student, "25CE099")
    first = request_change(client, device_id="dev-B")
    assert first.status_code == 409
    assert first.json()["code"] == "device_not_bound"
    login(client, device_id="dev-A")
    same = request_change(client, device_id="dev-A")
    assert same.status_code == 409
    assert same.json()["code"] == "same_device"


def test_second_request_replaces_pending_one(client, db, make_user):
    make_user(UserRole.student, "25CE099")
    login(client, device_id="dev-A")
    request_change(client, device_id="dev-B", reason="lần một")
    request_change(client, device_id="dev-C", reason="lần hai")
    rows = list(db.scalars(select(DeviceChangeRequest)))
    assert len(rows) == 1
    assert rows[0].new_device_id == "dev-C"
    assert rows[0].reason == "lần hai"


def test_only_students_can_request(client, make_user):
    make_user(UserRole.teacher, "T001")
    response = request_change(client, ident="T001")
    assert response.status_code == 401


def test_admin_lists_pending_requests(client, make_user, auth):
    make_user(UserRole.student, "25CE099", name="Nguyen Van A")
    admin = make_user(UserRole.admin, "A001")
    login(client, device_id="dev-A")
    request_change(client)
    response = client.get("/admin/device-requests?status=pending", headers=auth(admin))
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 1
    assert items[0]["student_id"] == "25CE099"
    assert items[0]["student_name"] == "Nguyen Van A"
    assert items[0]["status"] == "pending"


def test_list_requires_admin(client, make_user, auth):
    teacher = make_user(UserRole.teacher, "T001")
    assert client.get("/admin/device-requests", headers=auth(teacher)).status_code == 403


def test_approve_switches_device_and_notifies(client, db, make_user, auth):
    student = make_user(UserRole.student, "25CE099")
    admin = make_user(UserRole.admin, "A001")
    login(client, device_id="dev-A")
    request_id = request_change(client).json()["id"]

    response = client.post(f"/admin/device-requests/{request_id}/approve", headers=auth(admin))
    assert response.status_code == 200
    assert response.json()["status"] == "approved"

    assert login(client, device_id="dev-B").status_code == 200
    assert login(client, device_id="dev-A").status_code == 403
    note = db.scalar(select(Notification).where(Notification.user_id == student.id))
    assert note.type == "device_change_approved"


def test_reject_keeps_old_device_and_notifies(client, db, make_user, auth):
    student = make_user(UserRole.student, "25CE099")
    admin = make_user(UserRole.admin, "A001")
    login(client, device_id="dev-A")
    request_id = request_change(client).json()["id"]

    response = client.post(f"/admin/device-requests/{request_id}/reject", headers=auth(admin))
    assert response.status_code == 200
    assert response.json()["status"] == "rejected"

    assert login(client, device_id="dev-B").status_code == 403
    assert login(client, device_id="dev-A").status_code == 200
    note = db.scalar(select(Notification).where(Notification.user_id == student.id))
    assert note.type == "device_change_rejected"


def test_cannot_resolve_twice(client, make_user, auth):
    make_user(UserRole.student, "25CE099")
    admin = make_user(UserRole.admin, "A001")
    login(client, device_id="dev-A")
    request_id = request_change(client).json()["id"]
    client.post(f"/admin/device-requests/{request_id}/approve", headers=auth(admin))
    again = client.post(f"/admin/device-requests/{request_id}/reject", headers=auth(admin))
    assert again.status_code == 409
    assert again.json()["code"] == "request_resolved"


def test_resolve_unknown_request_is_404(client, make_user, auth):
    admin = make_user(UserRole.admin, "A001")
    response = client.post("/admin/device-requests/999/approve", headers=auth(admin))
    assert response.status_code == 404
