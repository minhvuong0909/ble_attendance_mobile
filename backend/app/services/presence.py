import math
from datetime import datetime
from statistics import median

WINDOW_SECONDS = 30
PRESENT_THRESHOLD = 0.6

Sample = tuple[datetime, int]


def total_windows(starts_at: datetime, ends_at: datetime) -> int:
    seconds = (ends_at - starts_at).total_seconds()
    return max(1, math.ceil(seconds / WINDOW_SECONDS))


def window_index(starts_at: datetime, moment: datetime) -> int:
    return math.floor((moment - starts_at).total_seconds() / WINDOW_SECONDS)


def valid_window_count(
    starts_at: datetime,
    ends_at: datetime,
    samples: list[Sample],
    rssi_threshold: int,
) -> int:
    total = total_windows(starts_at, ends_at)
    buckets: dict[int, list[int]] = {}
    for moment, rssi in samples:
        index = window_index(starts_at, moment)
        if 0 <= index < total:
            buckets.setdefault(index, []).append(rssi)
    return sum(1 for values in buckets.values() if median(values) > rssi_threshold)


def presence_ratio(
    starts_at: datetime,
    ends_at: datetime,
    samples: list[Sample],
    rssi_threshold: int,
) -> float:
    valid = valid_window_count(starts_at, ends_at, samples, rssi_threshold)
    return min(1.0, round(valid / total_windows(starts_at, ends_at), 3))


def first_seen_at(
    samples: list[Sample],
    starts_at: datetime,
    ends_at: datetime,
    rssi_threshold: int,
) -> datetime | None:
    moments = [
        moment
        for moment, rssi in samples
        if starts_at <= moment <= ends_at and rssi > rssi_threshold
    ]
    return min(moments) if moments else None
