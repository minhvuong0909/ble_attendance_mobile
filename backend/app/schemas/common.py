from datetime import datetime, timezone
from typing import Annotated

from pydantic import PlainSerializer


def _to_utc_iso(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


# Datetime lưu dạng naive UTC; khi trả ra JSON luôn kèm "Z" để client không hiểu nhầm là giờ địa phương.
UtcDateTime = Annotated[datetime, PlainSerializer(_to_utc_iso, return_type=str, when_used="json")]
