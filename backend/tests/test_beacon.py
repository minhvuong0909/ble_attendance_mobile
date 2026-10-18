from datetime import datetime, timedelta

from app.services.beacon import bucket_of, make_tag, student_secret, verify_tag

OBSERVED = datetime(2026, 10, 18, 0, 0, 0)


def test_bucket_of_known_value():
    assert bucket_of(OBSERVED) == 59742720
    assert bucket_of(OBSERVED + timedelta(seconds=29)) == 59742720
    assert bucket_of(OBSERVED + timedelta(seconds=30)) == 59742721


def test_make_tag_known_vector():
    assert make_tag("abc", 100) == "a18217a4"


def test_student_secret_known_vector():
    # BEACON_SERVER_KEY=key được đặt trong tests/conftest.py
    assert student_secret("sess-1", "25CE099") == (
        "a28f493f3749b2e8b46830fd47be832c359f7d9fc2177827c8fd4bddd2628f59"
    )


def test_verify_accepts_current_and_adjacent_buckets():
    secret = student_secret("s", "25CE099")
    current = bucket_of(OBSERVED)
    for bucket in (current - 1, current, current + 1):
        assert verify_tag(secret, bucket, make_tag(secret, bucket), OBSERVED)


def test_verify_rejects_bucket_two_away():
    secret = student_secret("s", "25CE099")
    bucket = bucket_of(OBSERVED) + 2
    assert not verify_tag(secret, bucket, make_tag(secret, bucket), OBSERVED)


def test_verify_rejects_wrong_tag_and_wrong_secret():
    secret = student_secret("s", "25CE099")
    bucket = bucket_of(OBSERVED)
    assert not verify_tag(secret, bucket, "00000000", OBSERVED)
    other = student_secret("s", "25CE100")
    assert not verify_tag(secret, bucket, make_tag(other, bucket), OBSERVED)


def test_verify_is_case_insensitive_for_hex():
    secret = student_secret("s", "25CE099")
    bucket = bucket_of(OBSERVED)
    assert verify_tag(secret, bucket, make_tag(secret, bucket).upper(), OBSERVED)
