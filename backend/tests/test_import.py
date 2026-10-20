from io import BytesIO

import pytest
from openpyxl import Workbook
from sqlalchemy import func, select

from app.models import ClassRoom, Course, Enrollment, User, UserRole


@pytest.fixture()
def admin(make_user):
    return make_user(UserRole.admin, "A001")


def csv_file(text, name="data.csv", bom=True):
    raw = text.encode("utf-8")
    return {"file": (name, (b"\xef\xbb\xbf" + raw) if bom else raw, "text/csv")}


def xlsx_file(rows, name="data.xlsx"):
    workbook = Workbook()
    for row in rows:
        workbook.active.append(row)
    buffer = BytesIO()
    workbook.save(buffer)
    return {"file": (name, buffer.getvalue(), "application/octet-stream")}


def user_count(db):
    return db.scalar(select(func.count(User.id)))


def enrollment_count(db):
    return db.scalar(select(func.count(Enrollment.id)))


STUDENTS_CSV = "student_id,full_name\n 25ce099 , Nguyen Van A \n\n25CE100,Tran Thi B\nD26CE045,Le Van C\n"


def import_students(client, auth, admin, cls, files, dry_run=None):
    suffix = "" if dry_run is None else f"?dry_run={str(dry_run).lower()}"
    return client.post(f"/admin/classes/{cls.id}/import-students{suffix}", files=files, headers=auth(admin))


def test_csv_import_creates_accounts_and_enrollments(client, auth, db, admin, make_class):
    cls = make_class()
    response = import_students(client, auth, admin, cls, csv_file(STUDENTS_CSV))
    assert response.status_code == 200
    body = response.json()
    assert body["committed"] is True and body["dry_run"] is False
    assert (body["total"], body["created"], body["skipped"], body["errors"]) == (3, 3, 0, 0)
    assert [r["row"] for r in body["rows"]] == [2, 4, 5]  # dòng trống (3) bị bỏ qua nhưng số dòng giữ đúng
    assert enrollment_count(db) == 3

    login = client.post("/auth/login", json={"identifier": "25ce099", "password": "25CE099"})
    assert login.status_code == 200
    assert login.json()["must_change_password"] is True
    assert db.scalar(select(User).where(User.student_id == "25CE099")).full_name == "Nguyen Van A"


def test_xlsx_import_matches_csv(client, auth, db, admin, make_class):
    cls = make_class()
    files = xlsx_file([["Student_ID", "Full_Name"], ["25CE099", "Nguyen Van A"], ["25CE100", "Tran Thi B"]])
    body = import_students(client, auth, admin, cls, files).json()
    assert (body["created"], body["errors"], body["committed"]) == (2, 0, True)
    assert enrollment_count(db) == 2


def test_dry_run_reports_but_writes_nothing(client, auth, db, admin, make_class):
    cls = make_class()
    body = import_students(client, auth, admin, cls, csv_file(STUDENTS_CSV), dry_run=True).json()
    assert body["dry_run"] is True and body["committed"] is False
    assert (body["total"], body["created"], body["errors"]) == (3, 3, 0)
    assert user_count(db) == 1  # chỉ có admin
    assert enrollment_count(db) == 0


def test_any_error_row_blocks_the_whole_import(client, auth, db, admin, make_class):
    cls = make_class()
    text = "student_id,full_name\n25CE099,Nguyen Van A\nBAD,Ten Sai Ma\n25CE100,\n"
    body = import_students(client, auth, admin, cls, csv_file(text)).json()
    assert body["committed"] is False
    assert (body["created"], body["errors"]) == (1, 2)
    statuses = {r["row"]: r["status"] for r in body["rows"]}
    assert statuses == {2: "created", 3: "error", 4: "error"}
    assert user_count(db) == 1
    assert enrollment_count(db) == 0


def test_duplicate_id_inside_the_file_is_an_error_on_the_later_row(client, auth, db, admin, make_class):
    cls = make_class()
    text = "student_id,full_name\n25CE099,Nguyen Van A\n25ce099,Nguyen Van A Lai\n"
    body = import_students(client, auth, admin, cls, csv_file(text)).json()
    assert [r["status"] for r in body["rows"]] == ["created", "error"]
    assert "trùng" in body["rows"][1]["message"]
    assert body["committed"] is False


def test_existing_student_is_reused_and_already_enrolled_is_skipped(client, auth, db, admin, make_class, make_user, enroll):
    cls = make_class()
    existing = make_user(UserRole.student, "25CE099", name="Da Co")
    enrolled = make_user(UserRole.student, "25CE100")
    enroll(cls, enrolled)
    text = "student_id,full_name\n25CE099,Doi Ten\n25CE100,Ten Khac\n"
    body = import_students(client, auth, admin, cls, csv_file(text)).json()
    assert [r["status"] for r in body["rows"]] == ["created", "skipped"]
    assert body["committed"] is True
    assert enrollment_count(db) == 2
    assert user_count(db) == 3  # admin + 2 SV, không tạo thêm tài khoản
    assert db.get(User, existing.id).full_name == "Da Co"


def test_student_id_used_by_a_teacher_is_an_error(client, auth, admin, make_class, make_user):
    cls = make_class()
    make_user(UserRole.teacher, "25CE099")
    body = import_students(client, auth, admin, cls, csv_file("student_id,full_name\n25CE099,Nguyen Van A\n")).json()
    assert body["rows"][0]["status"] == "error"
    assert body["committed"] is False


def test_missing_columns_is_422(client, auth, admin, make_class):
    cls = make_class()
    response = import_students(client, auth, admin, cls, csv_file("ma,ten\n25CE099,An\n"))
    assert response.status_code == 422
    assert response.json()["code"] == "missing_columns"
    assert "student_id" in response.json()["detail"]


def test_empty_file_is_missing_columns(client, auth, admin, make_class):
    cls = make_class()
    response = import_students(client, auth, admin, cls, csv_file("", bom=False))
    assert response.status_code == 422
    assert response.json()["code"] == "missing_columns"


def test_file_validation(client, auth, admin, make_class):
    cls = make_class()
    wrong_ext = import_students(client, auth, admin, cls, {"file": ("data.txt", b"x", "text/plain")})
    assert (wrong_ext.status_code, wrong_ext.json()["code"]) == (422, "unsupported_file")
    broken = import_students(client, auth, admin, cls, {"file": ("data.xlsx", b"not a zip", "application/octet-stream")})
    assert (broken.status_code, broken.json()["code"]) == (422, "file_unreadable")
    huge = import_students(client, auth, admin, cls, {"file": ("data.csv", b"a" * 2_000_001, "text/csv")})
    assert (huge.status_code, huge.json()["code"]) == (413, "file_too_large")


def test_permissions_and_unknown_class(client, auth, make_user, make_class, admin):
    cls = make_class()
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    for user in (teacher, student):
        assert import_students(client, auth, user, cls, csv_file(STUDENTS_CSV)).status_code == 403
        assert client.post("/admin/imports/teachers", files=csv_file("teacher_id,full_name\n"), headers=auth(user)).status_code == 403
    missing = client.post("/admin/classes/nope/import-students", files=csv_file(STUDENTS_CSV), headers=auth(admin))
    assert (missing.status_code, missing.json()["code"]) == (404, "class_not_found")


def test_teacher_import(client, auth, db, admin, make_user):
    make_user(UserRole.teacher, "T001")
    make_user(UserRole.student, "25CE099")
    text = "teacher_id,full_name\nt002,Thay Nam\nT001,Da Co\n25CE099,Trung Ma SV\nXY,Ma Qua Ngan\n"
    body = client.post("/admin/imports/teachers?dry_run=true", files=csv_file(text), headers=auth(admin)).json()
    assert [r["status"] for r in body["rows"]] == ["created", "skipped", "error", "error"]
    assert body["committed"] is False

    clean = "teacher_id,full_name\nt002,Thay Nam\nT001,Da Co\n"
    body = client.post("/admin/imports/teachers", files=csv_file(clean), headers=auth(admin)).json()
    assert (body["created"], body["skipped"], body["committed"]) == (1, 1, True)
    login = client.post("/auth/login", json={"identifier": "T002", "password": "T002"})
    assert login.status_code == 200 and login.json()["must_change_password"] is True


def test_class_import_creates_courses_classes_and_assigns_teacher(client, auth, db, admin, make_user, make_class):
    teacher = make_user(UserRole.teacher, "T001")
    make_class(course_code="PRM393", class_code="SE1901")  # đã tồn tại -> skipped, môn được dùng lại
    text = (
        "course_code,course_name,class_code,semester,teacher_id\n"
        "prm393,Mobile Programming,SE1901,FA26,\n"
        "PRM393,Mobile Programming,SE1902,FA26,t001\n"
        "SWE201,Software Engineering,SE1901,FA26,\n"
    )
    body = client.post("/admin/imports/classes", files=csv_file(text), headers=auth(admin)).json()
    assert [r["status"] for r in body["rows"]] == ["skipped", "created", "created"]
    assert body["committed"] is True
    assert db.scalar(select(func.count(Course.id))) == 2
    created = db.scalar(select(ClassRoom).where(ClassRoom.class_code == "SE1902"))
    assert created.teacher_user_id == teacher.id
    assert len(created.join_code) == 6


def test_class_import_errors(client, auth, db, admin):
    text = (
        "course_code,course_name,class_code,semester,teacher_id\n"
        "NEW100,,SE1901,FA26,\n"
        "NEW200,Mon Moi,SE1901,FA26,T999\n"
    )
    body = client.post("/admin/imports/classes", files=csv_file(text), headers=auth(admin)).json()
    assert [r["status"] for r in body["rows"]] == ["error", "error"]
    assert body["committed"] is False
    assert db.scalar(select(func.count(Course.id))) == 0


@pytest.mark.parametrize(
    "kind,header",
    [
        ("students", "student_id,full_name"),
        ("teachers", "teacher_id,full_name"),
        ("classes", "course_code,course_name,class_code,semester,teacher_id"),
    ],
)
def test_templates(client, auth, admin, kind, header):
    response = client.get(f"/admin/imports/templates/{kind}", headers=auth(admin))
    assert response.status_code == 200
    assert response.content.startswith(b"\xef\xbb\xbf")
    assert response.content.decode("utf-8-sig").splitlines()[0] == header
    assert f"{kind}_template.csv" in response.headers["content-disposition"]


def test_unknown_template_is_404(client, auth, admin):
    assert client.get("/admin/imports/templates/nope", headers=auth(admin)).status_code == 404


def test_every_row_echoes_the_file_data_so_the_preview_can_show_it(client, auth, admin):
    csv = "teacher_id,full_name\nT901,Trần Văn B\nT902,Lê Thị C\n"
    body = client.post(
        "/admin/imports/teachers", params={"dry_run": True}, files=csv_file(csv), headers=auth(admin)
    ).json()
    assert [r["data"] for r in body["rows"]] == [
        {"teacher_id": "T901", "full_name": "Trần Văn B"},
        {"teacher_id": "T902", "full_name": "Lê Thị C"},
    ]
    classes = "course_code,course_name,class_code,semester,teacher_id\nPRM393,Lập trình,SE1901,FA26,T001\n"
    body = client.post(
        "/admin/imports/classes", params={"dry_run": True}, files=csv_file(classes), headers=auth(admin)
    ).json()
    assert body["rows"][0]["data"]["class_code"] == "SE1901"
    assert body["rows"][0]["data"]["course_name"] == "Lập trình"
