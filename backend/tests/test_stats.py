from datetime import datetime, timedelta

import pytest

from app.core.clock import utcnow
from app.models import Attendance, AttendanceStatus, LectureSession, UserRole
from app.services.stats import class_stats, late_minutes

BASE = datetime(2026, 10, 1, 3, 0, 0)


@pytest.fixture()
def world(make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    return teacher, student, cls


def add_session(db, cls, teacher, day, active=False):
    starts = BASE + timedelta(days=day)
    session = LectureSession(
        class_id=cls.id,
        teacher_user_id=teacher.id,
        token=f"token{day:011d}",
        starts_at=starts,
        ends_at=None if active else starts + timedelta(hours=1),
        is_active=active,
    )
    db.add(session)
    db.commit()
    return session


def add_row(db, session, student, status, ratio=0.0, first_seen=None):
    db.add(
        Attendance(
            session_id=session.id,
            student_user_id=student.id,
            status=status,
            presence_ratio=ratio,
            first_seen_at=first_seen,
        )
    )
    db.commit()


def fill(db, cls, teacher, student, statuses):
    for day, status in enumerate(statuses):
        add_row(db, add_session(db, cls, teacher, day), student, status)


def test_class_stats_percentages(db, world):
    teacher, student, cls = world
    fill(db, cls, teacher, student, ["present"] * 3 + ["absent", "excused"])
    stats = class_stats(db, cls, student.id)
    assert (stats.total, stats.present, stats.absent, stats.excused) == (5, 3, 1, 1)
    assert stats.attendance_percent == 80.0
    assert stats.absent_percent == 20.0


def test_warning_only_when_absent_percent_exceeds_limit(db, world):
    teacher, student, cls = world
    fill(db, cls, teacher, student, ["present"] * 4 + ["absent"])  # đúng 20% = ngưỡng
    assert class_stats(db, cls, student.id).warning is False
    add_row(db, add_session(db, cls, teacher, 10), student, AttendanceStatus.absent)  # 2/6 = 33%
    assert class_stats(db, cls, student.id).warning is True


def test_no_sessions_means_full_attendance_and_no_warning(db, world):
    _, student, cls = world
    stats = class_stats(db, cls, student.id)
    assert stats.total == 0
    assert stats.attendance_percent == 100.0
    assert stats.absent_percent == 0.0
    assert stats.warning is False


def test_active_sessions_are_not_counted(db, world):
    teacher, student, cls = world
    add_row(db, add_session(db, cls, teacher, 0, active=True), student, AttendanceStatus.absent)
    assert class_stats(db, cls, student.id).total == 0


def test_sessions_without_a_row_for_the_student_are_not_counted(db, world):
    teacher, student, cls = world
    add_session(db, cls, teacher, 0)  # buổi cũ trước khi SV vào lớp, không có bản ghi
    add_row(db, add_session(db, cls, teacher, 1), student, AttendanceStatus.present)
    stats = class_stats(db, cls, student.id)
    assert stats.total == 1
    assert stats.absent == 0


@pytest.mark.parametrize(
    "offset_seconds,expected", [(0, 0), (59, 0), (60, 1), (239, 3), (-30, 0)]
)
def test_late_minutes(offset_seconds, expected):
    starts = datetime(2026, 10, 18, 3, 0, 0)
    assert late_minutes(starts, starts + timedelta(seconds=offset_seconds)) == expected


def test_late_minutes_none_without_first_seen():
    assert late_minutes(datetime(2026, 10, 18, 3, 0, 0), None) is None


def test_me_attendance_lists_ended_sessions_newest_first(client, auth, db, world):
    teacher, student, cls = world
    first = add_session(db, cls, teacher, 0)
    second = add_session(db, cls, teacher, 1)
    add_row(db, first, student, AttendanceStatus.present, 0.9, first_seen=first.starts_at + timedelta(minutes=3, seconds=10))
    add_row(db, second, student, AttendanceStatus.absent)
    response = client.get(f"/me/attendance?class_id={cls.id}", headers=auth(student))
    assert response.status_code == 200
    body = response.json()
    assert [row["session_id"] for row in body] == [second.id, first.id]
    assert body[1]["late_minutes"] == 3
    assert body[1]["first_seen_at"].endswith("Z")
    assert body[0]["late_minutes"] is None
    assert body[0]["status"] == "absent"


def test_me_attendance_requires_class_id_and_membership(client, auth, make_user, make_class, world):
    _, student, cls = world
    assert client.get("/me/attendance", headers=auth(student)).status_code == 422
    other_class = make_class(class_code="SE1999")
    response = client.get(f"/me/attendance?class_id={other_class.id}", headers=auth(student))
    assert response.status_code == 404
    assert response.json()["code"] == "class_not_found"


def test_me_attendance_stats_per_class(client, auth, db, world, make_class):
    teacher, student, cls = world
    fill(db, cls, teacher, student, ["present", "present", "absent"])
    response = client.get("/me/attendance/stats", headers=auth(student))
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    entry = body[0]
    assert entry["class_id"] == cls.id
    assert entry["course_code"] == "PRM393"
    assert entry["total_sessions"] == 3
    assert entry["present"] == 2 and entry["absent"] == 1 and entry["excused"] == 0
    assert entry["attendance_percent"] == 66.7
    assert entry["absent_percent"] == 33.3
    assert entry["max_absence_percent"] == 20
    assert entry["warning"] is True


def test_me_endpoints_are_student_only(client, auth, world):
    teacher, _, cls = world
    assert client.get("/me/attendance/stats", headers=auth(teacher)).status_code == 403
    assert client.get(f"/me/attendance?class_id={cls.id}", headers=auth(teacher)).status_code == 403
