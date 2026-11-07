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
    response = client.post("/auth/login", json={"identifier": " 25ce099 ", "password": "Pass@123", "device_id": "dev-test-1"})
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
