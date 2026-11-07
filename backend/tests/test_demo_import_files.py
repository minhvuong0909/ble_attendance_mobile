"""Bộ file nhập mẫu trong docs/demo-import phải luôn nhập được vào dữ liệu seed."""
from pathlib import Path

import pytest

from app.models import UserRole
from app.services.seed import seed

FOLDER = Path(__file__).resolve().parents[2] / "docs" / "demo-import"

STUDENT_FILES = [
    ("03_sv_SWP391_SE1920.csv", "SWP391", "SE1920"),
    ("03_sv_SWT301_SE1920.csv", "SWT301", "SE1920"),
    ("03_sv_PRM393_SE1920.csv", "PRM393", "SE1920"),
    ("03_sv_PRN232_SE1921.xlsx", "PRN232", "SE1921"),
    ("03_sv_MLN122_EL1903.csv", "MLN122", "EL1903"),
]


def upload(client, url, headers, filename, dry_run=False):
    content = (FOLDER / filename).read_bytes()
    return client.post(
        f"{url}{'?dry_run=true' if dry_run else ''}",
        files={"file": (filename, content)},
        headers=headers,
    )


@pytest.fixture()
def admin_headers(db, make_user, auth):
    seed(db)
    return auth(make_user(UserRole.admin, "A777"))


def class_id(client, headers, course, code):
    classes = client.get("/admin/classes", headers=headers).json()
    return next(c["id"] for c in classes if c["course_code"] == course and c["class_code"] == code)


def test_teacher_file_creates_four_accounts(client, admin_headers):
    report = upload(client, "/admin/imports/teachers", admin_headers, "01_giang_vien.csv").json()
    assert (report["errors"], report["created"], report["committed"]) == (0, 4, True)


def test_class_file_creates_classes_and_new_courses(client, admin_headers):
    upload(client, "/admin/imports/teachers", admin_headers, "01_giang_vien.csv")
    report = upload(client, "/admin/imports/classes", admin_headers, "02_lop_hoc.csv").json()
    assert (report["errors"], report["created"], report["committed"]) == (0, 5, True)
    courses = {c["code"] for c in client.get("/admin/courses", headers=admin_headers).json()}
    assert {"SWP391", "SWT301", "MLN122", "PRM393", "PRN232"} <= courses


def test_class_file_needs_the_teacher_file_first(client, admin_headers):
    report = upload(client, "/admin/imports/classes", admin_headers, "02_lop_hoc.csv").json()
    assert report["errors"] > 0
    assert report["committed"] is False


@pytest.mark.parametrize(("filename", "course", "code"), STUDENT_FILES)
def test_every_student_file_imports_cleanly(client, admin_headers, filename, course, code):
    upload(client, "/admin/imports/teachers", admin_headers, "01_giang_vien.csv")
    upload(client, "/admin/imports/classes", admin_headers, "02_lop_hoc.csv")
    cid = class_id(client, admin_headers, course, code)
    report = upload(client, f"/admin/classes/{cid}/import-students", admin_headers, filename).json()
    assert report["errors"] == 0, report["rows"]
    assert report["committed"] is True
    assert report["created"] >= 12


def test_error_file_is_blocked_with_three_bad_rows(client, admin_headers):
    upload(client, "/admin/imports/teachers", admin_headers, "01_giang_vien.csv")
    upload(client, "/admin/imports/classes", admin_headers, "02_lop_hoc.csv")
    cid = class_id(client, admin_headers, "SWP391", "SE1920")
    report = upload(client, f"/admin/classes/{cid}/import-students", admin_headers, "99_loi_demo.csv").json()
    assert report["errors"] == 3
    assert report["committed"] is False
    assert report["created"] == 2


def test_a_self_registered_student_is_assigned_to_a_class_by_the_admin(client, admin_headers):
    """Sinh viên tự đăng ký chưa có lớp nào; admin xếp lớp bằng file, sinh viên mới thấy lớp."""
    register = client.post(
        "/auth/register",
        json={"full_name": "Sinh viên Mới", "identifier": "26CE777", "password": "Pass@123"},
    )
    assert register.status_code == 201
    login = client.post(
        "/auth/login",
        json={"identifier": "26CE777", "password": "Pass@123", "device_id": "dev-new-0001"},
    ).json()
    student = {"Authorization": f"Bearer {login['access_token']}"}
    assert client.get("/classes/mine", headers=student).json() == []

    cid = class_id(client, admin_headers, "MLN131", "Half2_EL1902")
    report = upload(
        client, f"/admin/classes/{cid}/import-students", admin_headers, "04_xep_lop_sv_moi.csv"
    ).json()
    assert (report["errors"], report["created"], report["committed"]) == (0, 1, True)
    assert report["rows"][0]["message"] == "Thêm vào lớp"  # tài khoản đã có, chỉ xếp lớp

    mine = client.get("/classes/mine", headers=student).json()
    assert [c["class_code"] for c in mine] == ["Half2_EL1902"]
