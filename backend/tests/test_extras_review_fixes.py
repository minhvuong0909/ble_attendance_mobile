from datetime import date, datetime, timedelta
from io import BytesIO

import pytest
from openpyxl import load_workbook
from sqlalchemy import func, select, update

from app.models import (
    Attendance,
    AttendanceStatus,
    LeaveRequest,
    LeaveStatus,
    LectureSession,
    Notification,
    UserRole,
)
from app.services.attendance import open_finalization
from app.services.leave import review_leave_request

STARTS = datetime(2026, 10, 18, 3, 0, 0)


def csv_file(text):
    return {"file": ("data.csv", b"\xef\xbb\xbf" + text.encode("utf-8"), "text/csv")}


def notification_count(db):
    return db.scalar(select(func.count(Notification.id)))


@pytest.fixture()
def world(make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    return teacher, student, cls


# --- Excel formula injection ---------------------------------------------------------

@pytest.mark.parametrize("name", ['=HYPERLINK("http://evil","x")', "+cmd|calc", "-1+1", "@SUM(1)"])
def test_exports_never_contain_formula_cells(client, auth, db, make_user, make_class, enroll, name):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099", name=name)
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    session = LectureSession(
        class_id=cls.id, teacher_user_id=teacher.id, token="abcdef0123456789",
        starts_at=STARTS, ends_at=STARTS + timedelta(hours=1), is_active=False,
    )
    db.add(session)
    db.flush()
    db.add(
        Attendance(
            session_id=session.id, student_user_id=student.id, status=AttendanceStatus.absent,
            overridden_by=teacher.id, override_reason=name,
        )
    )
    db.commit()

    for url in (f"/classes/{cls.id}/report/export", f"/sessions/{session.id}/export"):
        response = client.get(url, headers=auth(teacher))
        sheet = load_workbook(BytesIO(response.content)).active
        cells = [cell for row in sheet.iter_rows() for cell in row if cell.value is not None]
        assert all(cell.data_type != "f" for cell in cells), url
        assert any(cell.value == name for cell in cells), url


# --- Atomic open-finalization / leave review ------------------------------------------

def test_open_finalization_does_nothing_when_opened_by_another_request(db, world):
    teacher, student, cls = world
    session = LectureSession(class_id=cls.id, teacher_user_id=teacher.id, token="abcdef0123456789")
    db.add(session)
    db.commit()
    assert session.finalization_open is False  # bản sao trong bộ nhớ chưa biết request khác đã mở
    db.execute(
        update(LectureSession).where(LectureSession.id == session.id)
        .values(finalization_open=True).execution_options(synchronize_session=False)
    )

    assert open_finalization(db, session) is False
    assert notification_count(db) == 0


def test_open_finalization_notifies_once_when_it_wins(db, world):
    teacher, student, cls = world
    session = LectureSession(class_id=cls.id, teacher_user_id=teacher.id, token="abcdef0123456789")
    db.add(session)
    db.commit()
    assert open_finalization(db, session) is True
    db.commit()
    assert notification_count(db) == 1
    assert open_finalization(db, session) is False


def test_review_does_nothing_when_another_request_already_reviewed(db, world):
    teacher, student, cls = world
    ended = LectureSession(
        class_id=cls.id, teacher_user_id=teacher.id, token="abcdef0123456789",
        starts_at=STARTS, ends_at=STARTS + timedelta(hours=1), is_active=False,
    )
    db.add(ended)
    db.flush()
    db.add(Attendance(session_id=ended.id, student_user_id=student.id, status=AttendanceStatus.absent))
    leave = LeaveRequest(student_user_id=student.id, class_id=cls.id, date=date(2026, 10, 18), reason="Bị ốm")
    db.add(leave)
    db.commit()
    assert leave.status == LeaveStatus.pending
    db.execute(
        update(LeaveRequest).where(LeaveRequest.id == leave.id)
        .values(status=LeaveStatus.rejected).execution_options(synchronize_session=False)
    )

    assert review_leave_request(db, leave, teacher, "approved", None) is False
    db.commit()
    assert leave.status == LeaveStatus.rejected
    assert db.scalar(select(Attendance.status)) == AttendanceStatus.absent
    assert notification_count(db) == 0


# --- Import hardening -----------------------------------------------------------------

def test_malformed_csv_is_a_422_not_a_500(client, auth, make_user, make_class):
    admin = make_user(UserRole.admin, "A001")
    cls = make_class()
    huge_field = 'student_id,full_name\n25CE099,"' + "a" * 200_000 + '"\n'
    response = client.post(
        f"/admin/classes/{cls.id}/import-students", files=csv_file(huge_field), headers=auth(admin)
    )
    assert response.status_code == 422
    assert response.json()["code"] == "file_unreadable"


def test_overlong_values_become_row_errors(client, auth, make_user, make_class):
    admin = make_user(UserRole.admin, "A001")
    cls = make_class()
    students = f"student_id,full_name\n25CE099,{'x' * 300}\n25CE100,Ten Hop Le\n"
    body = client.post(
        f"/admin/classes/{cls.id}/import-students", files=csv_file(students), headers=auth(admin)
    ).json()
    assert [r["status"] for r in body["rows"]] == ["error", "created"]
    assert body["committed"] is False

    teachers = f"teacher_id,full_name\nT900,{'x' * 121}\n"
    body = client.post("/admin/imports/teachers", files=csv_file(teachers), headers=auth(admin)).json()
    assert body["rows"][0]["status"] == "error"

    classes = (
        "course_code,course_name,class_code,semester,teacher_id\n"
        f"{'C' * 33},Mon,SE1901,FA26,\n"
        f"ABC100,{'n' * 121},SE1901,FA26,\n"
        f"ABC200,Mon Hop Le,{'L' * 33},FA26,\n"
        f"ABC300,Mon Hop Le,SE1901,{'S' * 33},\n"
    )
    body = client.post("/admin/imports/classes", files=csv_file(classes), headers=auth(admin)).json()
    assert [r["status"] for r in body["rows"]] == ["error"] * 4
