from datetime import timedelta

import pytest
from sqlalchemy import select

from app.core.clock import utcnow
from app.models import Attendance, AttendanceStatus, Detection, UserRole


@pytest.fixture()
def live(client, auth, make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099", name="An")
    absent_student = make_user(UserRole.student, "25CE100", name="Binh")
    cls = make_class(teacher=teacher)
    enroll(cls, student, absent_student)
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    return teacher, student, absent_student, cls, session


def see(db, session, student, seconds_ago=10, rssi=-60):
    db.add(
        Detection(
            session_id=session["id"],
            student_user_id=student.id,
            rssi=rssi,
            detected_at=utcnow() - timedelta(seconds=seconds_ago),
        )
    )
    db.commit()


def open_finalization(client, auth, teacher, session):
    client.post(f"/sessions/{session['id']}/open-finalization", headers=auth(teacher))


def finalize(client, auth, student, session):
    return client.post("/attendance/finalize", json={"session_id": session["id"]}, headers=auth(student))


def test_finalize_requires_open_finalization(client, auth, live, db):
    _, student, _, _, session = live
    see(db, session, student)
    response = finalize(client, auth, student, session)
    assert response.status_code == 409
    assert response.json()["code"] == "finalization_not_open"


def test_finalize_requires_recent_detection(client, auth, live, db):
    teacher, student, _, _, session = live
    open_finalization(client, auth, teacher, session)
    response = finalize(client, auth, student, session)
    assert response.status_code == 409
    assert response.json()["code"] == "not_in_range"

    see(db, session, student, seconds_ago=120)
    assert finalize(client, auth, student, session).json()["code"] == "not_in_range"


def test_finalize_ignores_weak_recent_detection(client, auth, live, db):
    teacher, student, _, _, session = live
    open_finalization(client, auth, teacher, session)
    see(db, session, student, seconds_ago=5, rssi=-90)
    assert finalize(client, auth, student, session).json()["code"] == "not_in_range"


def test_finalize_success_marks_row(client, auth, live, db):
    teacher, student, _, _, session = live
    open_finalization(client, auth, teacher, session)
    see(db, session, student, seconds_ago=60)
    response = finalize(client, auth, student, session)
    assert response.status_code == 200
    assert response.json()["finalized"] is True
    row = db.scalar(select(Attendance).where(Attendance.student_user_id == student.id))
    assert row.finalized is True
    assert row.finalized_at is not None


def test_finalize_rejects_student_outside_class(client, auth, live, make_user, db):
    teacher, _, _, _, session = live
    outsider = make_user(UserRole.student, "25CE200")
    open_finalization(client, auth, teacher, session)
    response = finalize(client, auth, outsider, session)
    assert response.status_code == 404
    assert response.json()["code"] == "session_not_found"


def test_finalize_rejects_ended_session(client, auth, live, db):
    teacher, student, _, _, session = live
    open_finalization(client, auth, teacher, session)
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    response = finalize(client, auth, student, session)
    assert response.status_code == 409
    assert response.json()["code"] == "session_ended"


def test_teacher_cannot_finalize(client, auth, live):
    teacher, _, _, _, session = live
    assert finalize(client, auth, teacher, session).status_code == 403


def test_end_session_creates_rows_for_whole_class(client, auth, live, db):
    teacher, student, absent_student, _, session = live
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    rows = {r.student_user_id: r for r in db.scalars(select(Attendance))}
    assert set(rows) == {student.id, absent_student.id}
    assert all(r.status == AttendanceStatus.absent for r in rows.values())


def test_end_session_twice_does_not_recompute(client, auth, live, db):
    teacher, student, _, _, session = live
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    row = db.scalar(select(Attendance).where(Attendance.student_user_id == student.id))
    row.presence_ratio = 0.77
    db.commit()
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    db.expire_all()
    row = db.scalar(select(Attendance).where(Attendance.student_user_id == student.id))
    assert row.presence_ratio == 0.77


def test_live_attendance_lists_whole_class(client, auth, live, db):
    teacher, student, _, _, session = live
    see(db, session, student)
    response = client.get(f"/sessions/{session['id']}/attendance", headers=auth(teacher))
    assert response.status_code == 200
    body = response.json()
    assert body["total_students"] == 2
    assert body["present_students"] == 0
    by_id = {r["student_id"]: r for r in body["records"]}
    assert by_id["25CE099"]["detection_count"] == 1
    assert by_id["25CE100"]["detection_count"] == 0
    assert by_id["25CE100"]["status"] == "absent"


def test_attendance_list_rules(client, auth, live, make_user):
    teacher, student, _, _, session = live
    other = make_user(UserRole.teacher, "T002")
    admin = make_user(UserRole.admin, "A001")
    assert client.get(f"/sessions/{session['id']}/attendance", headers=auth(admin)).status_code == 200
    assert client.get(f"/sessions/{session['id']}/attendance", headers=auth(other)).status_code == 404
    assert client.get(f"/sessions/{session['id']}/attendance", headers=auth(student)).status_code == 403


def test_override_then_end_keeps_override(client, auth, live, db):
    teacher, student, _, _, session = live
    response = client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": student.id, "status": "present", "reason": "GV xác nhận có mặt"},
        headers=auth(teacher),
    )
    assert response.status_code == 200
    assert response.json()["status"] == "present"
    assert response.json()["overridden_by"] == teacher.id

    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    records = client.get(f"/sessions/{session['id']}/attendance", headers=auth(teacher)).json()["records"]
    mine = next(r for r in records if r["student_id"] == "25CE099")
    assert mine["status"] == "present"
    assert mine["overridden"] is True
    assert mine["override_reason"] == "GV xác nhận có mặt"


def test_student_finalize_after_override_does_not_change_status(client, auth, live, db):
    teacher, student, _, _, session = live
    client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": student.id, "status": "excused", "reason": "Có giấy phép"},
        headers=auth(teacher),
    )
    open_finalization(client, auth, teacher, session)
    see(db, session, student)
    assert finalize(client, auth, student, session).status_code == 200
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    row = db.scalar(select(Attendance).where(Attendance.student_user_id == student.id))
    db.refresh(row)
    assert row.status == AttendanceStatus.excused


def test_override_validation(client, auth, live, make_user):
    teacher, student, _, _, session = live
    short_reason = client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": student.id, "status": "present", "reason": "ok"},
        headers=auth(teacher),
    )
    assert short_reason.status_code == 422

    outsider = make_user(UserRole.student, "25CE200")
    not_in_class = client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": outsider.id, "status": "present", "reason": "Không thuộc lớp"},
        headers=auth(teacher),
    )
    assert not_in_class.status_code == 404
    assert not_in_class.json()["code"] == "student_not_in_class"


def test_student_cannot_override(client, auth, live):
    _, student, _, _, session = live
    response = client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": student.id, "status": "present", "reason": "Tự sửa điểm"},
        headers=auth(student),
    )
    assert response.status_code == 403
