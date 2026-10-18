from datetime import timedelta

import pytest
from sqlalchemy import func, select, update

from app.core.clock import utcnow
from app.models import Attendance, LectureSession, UserRole
from app.services.attendance import close_session


def test_close_session_does_nothing_when_closed_by_another_request(db, make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    session = LectureSession(
        class_id=cls.id,
        teacher_user_id=teacher.id,
        token="abcdef0123456789",
        starts_at=utcnow() - timedelta(minutes=5),
    )
    db.add(session)
    db.commit()
    assert session.is_active is True  # nạp bản sao trong bộ nhớ trước khi bị request khác đóng

    closed_at = utcnow() - timedelta(minutes=1)
    db.execute(
        update(LectureSession)
        .where(LectureSession.id == session.id)
        .values(is_active=False, ends_at=closed_at)
        .execution_options(synchronize_session=False)
    )

    assert close_session(db, session) is False
    db.refresh(session)
    assert session.ends_at == closed_at
    assert db.scalar(select(func.count(Attendance.id))) == 0


def test_close_session_closes_and_settles_whole_class(db, make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    session = LectureSession(
        class_id=cls.id, teacher_user_id=teacher.id, token="abcdef0123456789"
    )
    db.add(session)
    db.commit()

    assert close_session(db, session) is True
    db.commit()
    assert session.is_active is False
    assert session.ends_at is not None
    assert db.scalar(select(func.count(Attendance.id))) == 1


def test_teacher_id_cannot_reuse_an_existing_student_id(client, make_user, auth):
    admin = make_user(UserRole.admin, "A001")
    make_user(UserRole.student, "25CE099")
    response = client.post(
        "/admin/teachers", json={"teacher_id": "25ce099", "full_name": "Trùng mã"}, headers=auth(admin)
    )
    assert response.status_code == 409
    assert response.json()["code"] == "teacher_exists"


def test_student_cannot_register_with_an_existing_teacher_id(client, make_user):
    make_user(UserRole.teacher, "25CE100")
    response = client.post(
        "/auth/register",
        json={"full_name": "Trùng mã", "identifier": "25CE100", "password": "Pass@123"},
    )
    assert response.status_code == 409
    assert response.json()["code"] == "student_exists"


@pytest.fixture()
def ended_session(client, auth, make_user, make_class, enroll):
    first = make_user(UserRole.teacher, "T001")
    second = make_user(UserRole.teacher, "T002")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=first)
    enroll(cls, student)
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(first)).json()
    client.post(f"/sessions/{session['id']}/end", headers=auth(first))
    return first, second, student, cls, session


def test_new_class_teacher_gets_access_and_old_teacher_loses_it(client, auth, db, ended_session):
    first, second, student, cls, session = ended_session
    cls.teacher_user_id = second.id
    db.commit()

    assert client.get(f"/sessions/{session['id']}/attendance", headers=auth(second)).status_code == 200
    assert client.get(f"/sessions/{session['id']}/attendance", headers=auth(first)).status_code == 404

    override = {"student_user_id": student.id, "status": "present", "reason": "Giảng viên mới xác nhận"}
    assert (
        client.post(f"/sessions/{session['id']}/attendance/override", json=override, headers=auth(second)).status_code
        == 200
    )
    assert (
        client.post(f"/sessions/{session['id']}/attendance/override", json=override, headers=auth(first)).status_code
        == 404
    )


def test_session_times_are_serialized_as_utc_with_z(client, auth, make_user, make_class):
    teacher = make_user(UserRole.teacher, "T001")
    cls = make_class(teacher=teacher)
    started = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    assert started["starts_at"].endswith("Z")
    ended = client.post(f"/sessions/{started['id']}/end", headers=auth(teacher)).json()
    assert ended["ends_at"].endswith("Z")


def test_first_seen_is_serialized_with_z(client, auth, make_user, make_class, enroll, db):
    from app.models import Detection

    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    db.add(Detection(session_id=session["id"], student_user_id=student.id, rssi=-60, detected_at=utcnow()))
    db.commit()
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))

    body = client.get(f"/sessions/{session['id']}/attendance", headers=auth(teacher)).json()
    seen = [r["first_seen_at"] for r in body["records"] if r["first_seen_at"]]
    assert seen, "expected the student to have a first_seen_at"
    assert all(value.endswith("Z") for value in seen)
