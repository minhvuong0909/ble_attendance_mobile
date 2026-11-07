from datetime import timedelta

from app.core.clock import utcnow
from app.models import Notification, UserRole
from app.services.notifier import notify, notify_many


def seed_notifications(db, user, count=3, prefix="n"):
    for index in range(count):
        notify(db, user.id, "info", f"{prefix}{index}", "nội dung", ref_id=f"ref-{index}")
    db.commit()


def test_notify_adds_row_without_committing(db, make_user):
    user = make_user(UserRole.student, "25CE099")
    notification = notify(db, user.id, "info", "Tiêu đề", "Nội dung", ref_id="abc")
    assert notification.is_read is False
    db.rollback()
    assert db.query(Notification).count() == 0


def test_notify_many_creates_one_per_user(db, make_user):
    users = [make_user(UserRole.student, "25CE099"), make_user(UserRole.student, "25CE100")]
    notify_many(db, [u.id for u in users], "info", "Tiêu đề", "Nội dung")
    db.commit()
    assert db.query(Notification).count() == 2


def test_list_returns_only_own_notifications_newest_first(client, db, make_user, auth):
    me = make_user(UserRole.student, "25CE099")
    other = make_user(UserRole.student, "25CE100")
    seed_notifications(db, me, count=3)
    seed_notifications(db, other, count=2, prefix="x")
    response = client.get("/notifications", headers=auth(me))
    assert response.status_code == 200
    titles = [n["title"] for n in response.json()]
    assert titles == ["n2", "n1", "n0"]
    assert response.json()[0]["created_at"].endswith("Z")


def test_list_unread_only_and_limit(client, db, make_user, auth):
    me = make_user(UserRole.student, "25CE099")
    seed_notifications(db, me, count=3)
    first = db.query(Notification).order_by(Notification.id).first()
    first.is_read = True
    db.commit()
    unread = client.get("/notifications?unread_only=true", headers=auth(me)).json()
    assert len(unread) == 2
    assert len(client.get("/notifications?limit=1", headers=auth(me)).json()) == 1


def test_limit_out_of_range_is_rejected(client, make_user, auth):
    me = make_user(UserRole.student, "25CE099")
    assert client.get("/notifications?limit=0", headers=auth(me)).status_code == 422
    assert client.get("/notifications?limit=201", headers=auth(me)).status_code == 422


def test_unread_count_and_mark_read(client, db, make_user, auth):
    me = make_user(UserRole.student, "25CE099")
    seed_notifications(db, me, count=2)
    assert client.get("/notifications/unread-count", headers=auth(me)).json() == {"count": 2}
    first_id = client.get("/notifications", headers=auth(me)).json()[0]["id"]
    assert client.post(f"/notifications/{first_id}/read", headers=auth(me)).status_code == 200
    assert client.get("/notifications/unread-count", headers=auth(me)).json() == {"count": 1}


def test_cannot_read_someone_elses_notification(client, db, make_user, auth):
    me = make_user(UserRole.student, "25CE099")
    other = make_user(UserRole.student, "25CE100")
    seed_notifications(db, other, count=1)
    other_id = db.query(Notification).first().id
    response = client.post(f"/notifications/{other_id}/read", headers=auth(me))
    assert response.status_code == 404
    assert response.json()["code"] == "notification_not_found"


def test_read_all_returns_updated_count(client, db, make_user, auth):
    me = make_user(UserRole.student, "25CE099")
    seed_notifications(db, me, count=3)
    assert client.post("/notifications/read-all", headers=auth(me)).json() == {"updated": 3}
    assert client.post("/notifications/read-all", headers=auth(me)).json() == {"updated": 0}
    assert client.get("/notifications/unread-count", headers=auth(me)).json() == {"count": 0}


def test_requires_login(client):
    assert client.get("/notifications").status_code == 401


# --- Sự kiện: mở chốt và cảnh báo vắng ---

import pytest

from app.models import Attendance, AttendanceStatus, LectureSession


@pytest.fixture()
def class_with_students(make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    students = [make_user(UserRole.student, ident) for ident in ("25CE099", "25CE100", "25CE101")]
    cls = make_class(teacher=teacher)
    enroll(cls, *students)
    return teacher, students, cls


def notifications_of(db, user, type_=None):
    query = db.query(Notification).filter(Notification.user_id == user.id)
    if type_:
        query = query.filter(Notification.type == type_)
    return query.all()


def test_open_finalization_notifies_each_student_once(client, auth, db, class_with_students, make_user):
    teacher, students, cls = class_with_students
    outsider = make_user(UserRole.student, "25CE200")
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()

    client.post(f"/sessions/{session['id']}/open-finalization", headers=auth(teacher))
    client.post(f"/sessions/{session['id']}/open-finalization", headers=auth(teacher))

    for student in students:
        found = notifications_of(db, student, "finalization_open")
        assert len(found) == 1
        assert found[0].ref_id == session["id"]
    assert notifications_of(db, outsider) == []


def add_history(db, cls, teacher, student, statuses):
    for index, status in enumerate(statuses):
        starts = utcnow() - timedelta(days=30 - index)
        session = LectureSession(
            class_id=cls.id,
            teacher_user_id=teacher.id,
            token=f"hist{student.id[:4]}{index:08d}",
            starts_at=starts,
            ends_at=starts + timedelta(hours=1),
            is_active=False,
        )
        db.add(session)
        db.flush()
        db.add(Attendance(session_id=session.id, student_user_id=student.id, status=status))
    db.commit()


def test_ending_session_warns_only_students_over_the_absence_limit(client, auth, db, class_with_students):
    teacher, (always_present, mostly_absent, present_today), cls = class_with_students
    present, absent = AttendanceStatus.present, AttendanceStatus.absent
    add_history(db, cls, teacher, always_present, [present] * 4)  # vắng hôm nay: 1/5 = 20%, chưa vượt
    add_history(db, cls, teacher, mostly_absent, [present, absent, absent, absent])  # 4/5 = 80%
    add_history(db, cls, teacher, present_today, [present] * 4)

    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    client.post(
        f"/sessions/{session['id']}/attendance/override",
        json={"student_user_id": present_today.id, "status": "present", "reason": "Có mặt đầy đủ"},
        headers=auth(teacher),
    )
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))  # gọi lại không cảnh báo thêm

    warnings = notifications_of(db, mostly_absent, "absence_warning")
    assert len(warnings) == 1
    assert warnings[0].ref_id == cls.id
    assert "PRM393" in warnings[0].body
    assert "vắng 80% số buổi" in warnings[0].body  # số nguyên, không phải "80.0%"
    assert notifications_of(db, always_present, "absence_warning") == []
    assert notifications_of(db, present_today, "absence_warning") == []
