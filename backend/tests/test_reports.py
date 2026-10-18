import re
from datetime import datetime, timedelta
from io import BytesIO

import pytest
from openpyxl import load_workbook

from app.models import Attendance, AttendanceStatus, Detection, LectureSession, UserRole
from app.services.reports import safe_filename

BASE = datetime(2026, 10, 1, 3, 0, 0)  # 10:00 giờ địa phương
XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
P, A, E = AttendanceStatus.present, AttendanceStatus.absent, AttendanceStatus.excused


@pytest.fixture()
def world(db, make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    students = [make_user(UserRole.student, ident) for ident in ("25CE099", "25CE100", "25CE101")]
    cls = make_class(teacher=teacher)
    enroll(cls, *students)
    sessions = []
    for day in range(3):
        starts = BASE + timedelta(days=day)
        session = LectureSession(
            class_id=cls.id,
            teacher_user_id=teacher.id,
            token=f"rep{day:013d}",
            starts_at=starts,
            ends_at=starts + timedelta(hours=1),
            is_active=False,
        )
        db.add(session)
        sessions.append(session)
    db.commit()

    def row(session, student, status, **extra):
        db.add(Attendance(session_id=session.id, student_user_id=student.id, status=status, **extra))

    a, b, c = students
    row(sessions[0], a, P); row(sessions[1], a, P); row(sessions[2], a, A)
    row(sessions[0], b, P); row(sessions[2], b, E)  # b không có bản ghi buổi giữa
    db.commit()
    return teacher, students, cls, sessions


def load(response):
    return load_workbook(BytesIO(response.content)).active


def test_class_report_matrix_and_totals(client, auth, world):
    teacher, (a, b, c), cls, sessions = world
    response = client.get(f"/classes/{cls.id}/report", headers=auth(teacher))
    assert response.status_code == 200
    body = response.json()
    assert [s["id"] for s in body["sessions"]] == [s.id for s in sessions]
    by_id = {s["student_id"]: s for s in body["students"]}
    assert by_id["25CE099"]["cells"] == ["present", "present", "absent"]
    assert by_id["25CE099"]["attendance_percent"] == 66.7
    assert by_id["25CE099"]["absent_percent"] == 33.3
    assert by_id["25CE099"]["warning"] is True
    assert by_id["25CE100"]["cells"] == ["present", None, "excused"]
    assert by_id["25CE100"]["attendance_percent"] == 100.0
    assert by_id["25CE101"]["cells"] == [None, None, None]
    assert by_id["25CE101"]["attendance_percent"] == 100.0
    assert body["average_attendance_percent"] == 88.9
    assert [s["student_id"] for s in body["students"]] == ["25CE099", "25CE100", "25CE101"]


def test_empty_class_report(client, auth, make_user, make_class):
    teacher = make_user(UserRole.teacher, "T001")
    cls = make_class(teacher=teacher)
    body = client.get(f"/classes/{cls.id}/report", headers=auth(teacher)).json()
    assert body["sessions"] == [] and body["students"] == []
    assert body["average_attendance_percent"] == 100.0


@pytest.mark.parametrize("path", ["/classes/{cid}/report", "/classes/{cid}/report/export"])
def test_report_access_rules(client, auth, make_user, world, path):
    teacher, (student, *_), cls, _ = world
    other = make_user(UserRole.teacher, "T002")
    admin = make_user(UserRole.admin, "A001")
    url = path.format(cid=cls.id)
    assert client.get(url, headers=auth(teacher)).status_code == 200
    assert client.get(url, headers=auth(admin)).status_code == 200
    assert client.get(url, headers=auth(other)).status_code == 404
    assert client.get(url, headers=auth(student)).status_code == 403
    assert client.get(url).status_code == 401


def test_class_export_workbook(client, auth, world):
    teacher, _, cls, _ = world
    response = client.get(f"/classes/{cls.id}/report/export", headers=auth(teacher))
    assert response.status_code == 200
    assert response.headers["content-type"].startswith(XLSX)
    assert "attachment" in response.headers["content-disposition"]
    ws = load(response)
    assert "PRM393" in ws["A1"].value
    assert [c.value for c in ws[3]] == [
        "STT", "MSSV", "Họ tên", "01/10", "02/10", "03/10", "Có mặt", "Vắng", "Có phép", "% chuyên cần",
    ]
    assert [c.value for c in ws[4]] == [1, "25CE099", "25CE099", "P", "P", "A", 2, 1, 0, 66.7]
    assert [c.value for c in ws[5]] == [2, "25CE100", "25CE100", "P", None, "E", 1, 0, 1, 100.0]
    assert ws.max_row == 6


def test_export_filename_is_safe(client, auth, make_user, make_class):
    teacher = make_user(UserRole.teacher, "T001")
    cls = make_class(teacher=teacher, class_code="SE 19/01")
    response = client.get(f"/classes/{cls.id}/report/export", headers=auth(teacher))
    assert 'filename="attendance_PRM393_SE_19_01_FA26.xlsx"' in response.headers["content-disposition"]


def test_safe_filename_keeps_only_allowed_characters():
    name = safe_filename("PRM 393", "Học kỳ", "")
    assert re.fullmatch(r"[A-Za-z0-9_.-]+", name)
    assert safe_filename("Học kỳ") == "H_c_k"
    assert safe_filename("???") == "report"


def test_session_export_workbook(client, auth, db, world):
    teacher, (a, b, c), cls, sessions = world
    session = sessions[0]
    attendance_a = db.query(Attendance).filter_by(session_id=session.id, student_user_id=a.id).one()
    attendance_a.presence_ratio = 0.9
    attendance_a.finalized = True
    attendance_a.first_seen_at = session.starts_at + timedelta(minutes=3, seconds=10)
    db.add(Detection(session_id=session.id, student_user_id=a.id, rssi=-60, detected_at=session.starts_at))
    attendance_b = db.query(Attendance).filter_by(session_id=session.id, student_user_id=b.id).one()
    attendance_b.status = A
    attendance_b.overridden_by = teacher.id
    attendance_b.override_reason = "Vắng không phép"
    db.commit()

    response = client.get(f"/sessions/{session.id}/export", headers=auth(teacher))
    assert response.status_code == 200
    ws = load(response)
    assert [c.value for c in ws[3]] == [
        "STT", "MSSV", "Họ tên", "Số lần phát hiện", "% hiện diện", "Trạng thái",
        "Đã chốt", "Giờ đến", "Trễ (phút)", "Lý do chỉnh tay",
    ]
    assert [c.value for c in ws[4]] == [1, "25CE099", "25CE099", 1, 90.0, "Có mặt", "Có", "10:03", 3, None]
    assert [c.value for c in ws[5]] == [2, "25CE100", "25CE100", 0, 0.0, "Vắng", "Không", None, None, "Vắng không phép"]


def test_session_export_access_rules(client, auth, make_user, world):
    teacher, (student, *_), _, sessions = world
    other = make_user(UserRole.teacher, "T002")
    url = f"/sessions/{sessions[0].id}/export"
    assert client.get(url, headers=auth(teacher)).status_code == 200
    assert client.get(url, headers=auth(other)).status_code == 404
    assert client.get(url, headers=auth(student)).status_code == 403
