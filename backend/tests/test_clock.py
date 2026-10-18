from datetime import date, datetime, timedelta, timezone

from app.core.clock import local_date, to_naive_utc, utcnow


def test_utcnow_is_naive():
    assert utcnow().tzinfo is None


def test_to_naive_utc_converts_offset_to_utc():
    aware = datetime(2026, 10, 18, 10, 0, tzinfo=timezone(timedelta(hours=7)))
    assert to_naive_utc(aware) == datetime(2026, 10, 18, 3, 0)


def test_to_naive_utc_keeps_naive_value():
    value = datetime(2026, 10, 18, 3, 0)
    assert to_naive_utc(value) == value


def test_local_date_uses_utc_plus_7():
    assert local_date(datetime(2026, 10, 17, 23, 30)) == date(2026, 10, 18)
    assert local_date(datetime(2026, 10, 18, 3, 0)) == date(2026, 10, 18)
