from datetime import date, datetime, timedelta, timezone

from app.core.config import settings


def utcnow() -> datetime:
    """Giờ UTC dạng naive, thống nhất cho toàn bộ cột DateTime."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def to_naive_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def local_date(value: datetime) -> date:
    """Ngày theo giờ địa phương của một thời điểm UTC naive."""
    return (value + timedelta(hours=settings.local_utc_offset_hours)).date()
