from datetime import date, datetime, timedelta

import pytest

from app.models import (
    Attendance,
    AttendanceStatus,
    LeaveRequest,
    LeaveStatus,
    LectureSession,
    Notification,
    UserRole,
)

DAY = date(2026, 10, 18)
STARTS = datetime(2026, 10, 18, 3, 0, 0)  # 10:00 giờ địa phương ngày 18


@pytest.fixture()
def world(make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099", name="An")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    return teacher, student, cls


def submit(client, auth, student, cls, day=DAY, reason="Bị ốm phải đi khám"):
    return client.post(
        "/leave-requests",
        json={"class_id": cls.id, "date": day.isoformat(), "reason": reason},
        headers=auth(student),
    )


def review(client, auth, user, leave_id, decision="approved", note=None):
    return client.post(
        f"/leave-requests/{leave_id}/review",
        json={"decision": decision, "note": note},
        headers=auth(user),
    )


def test_student_submits_leave_and_teacher_is_notified(client, auth, db, world):
    teacher, student, cls = world
    response = submit(client, auth, student, cls)
    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "pending"
    assert body["student_id"] == "25CE099"
    assert body["course_code"] == "PRM393"
    assert body["date"] == "2026-10-18"
    notification = db.query(Notification).filter_by(user_id=teacher.id).one()
    assert notification.type == "leave_submitted"
    assert notification.ref_id == str(body["id"])


def test_student_outside_class_cannot_submit(client, auth, make_user, world):
    _, _, cls = world
    outsider = make_user(UserRole.student, "25CE200")
    response = submit(client, auth, outsider, cls)
    assert response.status_code == 404
    assert response.json()["code"] == "class_not_found"


def test_short_reason_is_rejected(client, auth, world):
    _, student, cls = world
    assert submit(client, auth, student, cls, reason="ok").status_code == 422


def test_only_students_can_submit(client, auth, world):
    teacher, _, cls = world
    assert submit(client, auth, teacher, cls).status_code == 403


def test_duplicate_open_request_is_rejected_but_rejected_one_can_be_resubmitted(client, auth, world):
    teacher, student, cls = world
    first = submit(client, auth, student, cls).json()
    duplicate = submit(client, auth, student, cls)
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "leave_exists"

    review(client, auth, teacher, first["id"], "rejected", "Thiếu giấy tờ")
    assert submit(client, auth, student, cls).status_code == 201
    other_day = submit(client, auth, student, cls, day=DAY + timedelta(days=1))
    assert other_day.status_code == 201


def test_mine_lists_only_own_requests_with_class_filter(client, auth, make_user, make_class, enroll, world):
    teacher, student, cls = world
    other_class = make_class(teacher=teacher, class_code="SE1902")
    enroll(other_class, student)
    other_student = make_user(UserRole.student, "25CE100")
    enroll(cls, other_student)
    submit(client, auth, student, cls)
    submit(client, auth, student, other_class)
    submit(client, auth, other_student, cls)

    assert len(client.get("/leave-requests/mine", headers=auth(student)).json()) == 2
    filtered = client.get(f"/leave-requests/mine?class_id={cls.id}", headers=auth(student)).json()
    assert [r["class_id"] for r in filtered] == [cls.id]


def test_class_list_access_and_status_filter(client, auth, make_user, world):
    teacher, student, cls = world
    other = make_user(UserRole.teacher, "T002")
    admin = make_user(UserRole.admin, "A001")
    first = submit(client, auth, student, cls).json()
    submit(client, auth, student, cls, day=DAY + timedelta(days=1))
    review(client, auth, teacher, first["id"], "approved")

    everything = client.get(f"/classes/{cls.id}/leave-requests", headers=auth(teacher)).json()
    assert len(everything) == 2
    pending = client.get(f"/classes/{cls.id}/leave-requests?status=pending", headers=auth(teacher)).json()
    assert [r["status"] for r in pending] == ["pending"]
    assert client.get(f"/classes/{cls.id}/leave-requests", headers=auth(admin)).status_code == 200
    assert client.get(f"/classes/{cls.id}/leave-requests", headers=auth(other)).status_code == 404
    assert client.get(f"/classes/{cls.id}/leave-requests", headers=auth(student)).status_code == 403


def test_review_notifies_student_and_stores_audit_fields(client, auth, db, world):
    teacher, student, cls = world
    leave = submit(client, auth, student, cls).json()
    response = review(client, auth, teacher, leave["id"], "approved", "Đã nhận giấy khám")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "approved"
    assert body["review_note"] == "Đã nhận giấy khám"
    assert body["reviewed_at"].endswith("Z")
    row = db.get(LeaveRequest, leave["id"])
    assert row.reviewed_by == teacher.id
    notification = db.query(Notification).filter_by(user_id=student.id).one()
    assert notification.type == "leave_reviewed"
    assert notification.ref_id == str(leave["id"])


def test_review_permissions_and_double_review(client, auth, make_user, world):
    teacher, student, cls = world
    other = make_user(UserRole.teacher, "T002")
    leave = submit(client, auth, student, cls).json()
    assert review(client, auth, student, leave["id"]).status_code == 403
    assert review(client, auth, other, leave["id"]).status_code == 404
    assert review(client, auth, teacher, leave["id"]).status_code == 200
    again = review(client, auth, teacher, leave["id"], "rejected")
    assert again.status_code == 409
    assert again.json()["code"] == "already_reviewed"


def test_review_unknown_request(client, auth, world):
    teacher, _, _ = world
    assert review(client, auth, teacher, 9999).status_code == 404


def add_settled_session(db, cls, teacher, student, status, overridden=False, starts=STARTS):
    session = LectureSession(
        class_id=cls.id,
        teacher_user_id=teacher.id,
        token=f"settled{status.value}{starts.day:02d}{starts.hour:02d}"[:16].ljust(16, "0"),
        starts_at=starts,
        ends_at=starts + timedelta(hours=1),
        is_active=False,
    )
    db.add(session)
    db.flush()
    db.add(
        Attendance(
            session_id=session.id,
            student_user_id=student.id,
            status=status,
            overridden_by=teacher.id if overridden else None,
        )
    )
    db.commit()
    return session


def status_of(db, session, student):
    return db.query(Attendance).filter_by(session_id=session.id, student_user_id=student.id).one().status


def test_approval_excuses_absent_settled_session_of_that_local_day(client, auth, db, world):
    teacher, student, cls = world
    same_day = add_settled_session(db, cls, teacher, student, AttendanceStatus.absent)
    # 23:30 UTC ngày 17 = 06:30 giờ địa phương ngày 18 -> cũng cùng ngày địa phương
    early = add_settled_session(db, cls, teacher, student, AttendanceStatus.absent, starts=datetime(2026, 10, 17, 23, 30, 0))
    next_day = add_settled_session(db, cls, teacher, student, AttendanceStatus.absent, starts=STARTS + timedelta(days=1))
    leave = submit(client, auth, student, cls).json()

    review(client, auth, teacher, leave["id"], "approved")

    assert status_of(db, same_day, student) == AttendanceStatus.excused
    assert status_of(db, early, student) == AttendanceStatus.excused
    assert status_of(db, next_day, student) == AttendanceStatus.absent


def test_approval_never_overwrites_override_or_present(client, auth, db, world, make_user, enroll):
    teacher, student, cls = world
    other_student = make_user(UserRole.student, "25CE100")
    enroll(cls, other_student)
    overridden = add_settled_session(db, cls, teacher, student, AttendanceStatus.absent, overridden=True)
    present_session = add_settled_session(
        db, cls, teacher, other_student, AttendanceStatus.present, starts=STARTS + timedelta(hours=2)
    )
    leave = submit(client, auth, student, cls).json()
    review(client, auth, teacher, leave["id"], "approved")
    assert status_of(db, overridden, student) == AttendanceStatus.absent

    leave2 = submit(client, auth, other_student, cls).json()
    review(client, auth, teacher, leave2["id"], "approved")
    assert status_of(db, present_session, other_student) == AttendanceStatus.present


def test_rejection_changes_nothing(client, auth, db, world):
    teacher, student, cls = world
    session = add_settled_session(db, cls, teacher, student, AttendanceStatus.absent)
    leave = submit(client, auth, student, cls).json()
    review(client, auth, teacher, leave["id"], "rejected")
    assert status_of(db, session, student) == AttendanceStatus.absent
