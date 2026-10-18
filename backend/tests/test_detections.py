from datetime import timedelta, timezone

import pytest
from sqlalchemy import func, select

from app.core.clock import utcnow
from app.models import Detection, LectureSession, UserRole
from app.services.beacon import bucket_of, make_tag, student_secret


@pytest.fixture()
def scenario(client, auth, make_user, make_class, enroll, db):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    session = client.post(f"/classes/{cls.id}/sessions", headers=auth(teacher)).json()
    # Buổi học đã bắt đầu 1 giờ trước để các quan sát trong quá khứ gần vẫn nằm trong buổi.
    row = db.get(LectureSession, session["id"])
    row.starts_at = utcnow() - timedelta(hours=1)
    db.commit()
    return teacher, student, session


def item(session, student_id, observed, rssi=-60, bucket=None, tag=None):
    bucket = bucket_of(observed) if bucket is None else bucket
    if tag is None:
        tag = make_tag(student_secret(session["id"], student_id), bucket)
    return {
        "session_id": session["id"],
        "student_identifier": student_id,
        "bucket": bucket,
        "tag": tag,
        "rssi": rssi,
        "observed_at": observed.isoformat() + "Z",
    }


def post(client, auth, teacher, *items):
    return client.post("/detections/batch", json={"detections": list(items)}, headers=auth(teacher))


def count(db):
    return db.scalar(select(func.count(Detection.id)))


def test_valid_detection_is_recorded(client, auth, scenario, db):
    teacher, _, session = scenario
    observed = utcnow() - timedelta(seconds=5)
    response = post(client, auth, teacher, item(session, "25CE099", observed))
    assert response.status_code == 200
    assert response.json() == {"recorded": 1, "rejected": 0}
    stored = db.scalar(select(Detection))
    assert stored.rssi == -60
    assert stored.detected_at == observed


def test_identifier_is_normalized(client, auth, scenario, db):
    teacher, _, session = scenario
    observed = utcnow()
    payload = item(session, "25CE099", observed)
    payload["student_identifier"] = " 25ce099 "
    assert post(client, auth, teacher, payload).json()["recorded"] == 1


def test_wrong_tag_is_rejected(client, auth, scenario, db):
    teacher, _, session = scenario
    response = post(client, auth, teacher, item(session, "25CE099", utcnow(), tag="00000000"))
    assert response.json() == {"recorded": 0, "rejected": 1}
    assert count(db) == 0


def test_bucket_one_away_accepted_two_away_rejected(client, auth, scenario):
    teacher, _, session = scenario
    observed = utcnow()
    base = bucket_of(observed)
    ok = item(session, "25CE099", observed, bucket=base + 1)
    bad = item(session, "25CE099", observed, bucket=base + 2)
    assert post(client, auth, teacher, ok, bad).json() == {"recorded": 1, "rejected": 1}


def test_student_outside_class_is_rejected(client, auth, scenario, make_user):
    teacher, _, session = scenario
    make_user(UserRole.student, "25CE100")
    response = post(client, auth, teacher, item(session, "25CE100", utcnow()))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_unknown_student_is_rejected(client, auth, scenario):
    teacher, _, session = scenario
    response = post(client, auth, teacher, item(session, "25CE777", utcnow()))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_other_teachers_session_is_rejected(client, auth, scenario, make_user):
    _, _, session = scenario
    other = make_user(UserRole.teacher, "T002")
    response = post(client, auth, other, item(session, "25CE099", utcnow()))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_ended_session_is_rejected(client, auth, scenario):
    teacher, _, session = scenario
    client.post(f"/sessions/{session['id']}/end", headers=auth(teacher))
    response = post(client, auth, teacher, item(session, "25CE099", utcnow()))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_observation_older_than_ten_minutes_is_rejected(client, auth, scenario):
    teacher, _, session = scenario
    response = post(client, auth, teacher, item(session, "25CE099", utcnow() - timedelta(minutes=11)))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_observation_before_session_start_is_rejected(client, auth, scenario, db):
    teacher, _, session = scenario
    row = db.get(LectureSession, session["id"])
    row.starts_at = utcnow() - timedelta(minutes=2)
    db.commit()
    # 5 phút trước: còn trong giới hạn 10 phút nhưng trước giờ bắt đầu buổi học.
    response = post(client, auth, teacher, item(session, "25CE099", utcnow() - timedelta(minutes=5)))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_observation_in_the_future_is_rejected(client, auth, scenario):
    teacher, _, session = scenario
    response = post(client, auth, teacher, item(session, "25CE099", utcnow() + timedelta(minutes=5)))
    assert response.json() == {"recorded": 0, "rejected": 1}


def test_observed_at_with_utc_offset_is_converted(client, auth, scenario, db):
    teacher, _, session = scenario
    observed = utcnow() - timedelta(seconds=2)
    local = observed.replace(tzinfo=timezone.utc).astimezone(timezone(timedelta(hours=7)))
    payload = item(session, "25CE099", observed)
    payload["observed_at"] = local.isoformat()
    assert post(client, auth, teacher, payload).json()["recorded"] == 1
    assert abs((db.scalar(select(Detection)).detected_at - observed).total_seconds()) < 1


def test_student_cannot_post_batch(client, auth, scenario):
    _, student, session = scenario
    response = post(client, auth, student, item(session, "25CE099", utcnow()))
    assert response.status_code == 403


def test_mixed_batch_counts(client, auth, scenario):
    teacher, _, session = scenario
    good = item(session, "25CE099", utcnow())
    bad = item(session, "25CE099", utcnow(), tag="deadbeef")
    assert post(client, auth, teacher, good, bad, good).json() == {"recorded": 2, "rejected": 1}
