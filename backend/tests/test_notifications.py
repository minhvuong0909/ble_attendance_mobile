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
