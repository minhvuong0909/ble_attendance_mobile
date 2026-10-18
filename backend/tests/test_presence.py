from datetime import datetime, timedelta

import pytest

from app.services.presence import (
    first_seen_at,
    presence_ratio,
    total_windows,
    valid_window_count,
)

START = datetime(2026, 10, 18, 3, 0, 0)
THRESHOLD = -75


def at(seconds):
    return START + timedelta(seconds=seconds)


@pytest.mark.parametrize("duration,expected", [(0, 1), (30, 1), (90, 3), (91, 4)])
def test_total_windows(duration, expected):
    assert total_windows(START, at(duration)) == expected


def test_ratio_counts_windows_not_packets():
    samples = [(at(s), -60) for s in (1, 5, 10, 15, 20, 65, 70)]
    assert valid_window_count(START, at(90), samples, THRESHOLD) == 2
    assert presence_ratio(START, at(90), samples, THRESHOLD) == 0.667


def test_many_packets_in_one_window_count_once():
    samples = [(at(1 + i * 0.1), -60) for i in range(100)]
    assert presence_ratio(START, at(90), samples, THRESHOLD) == 0.333


def test_window_with_weak_median_is_invalid():
    samples = [(at(s), r) for s, r in [(1, -60), (2, -60), (3, -95), (4, -95), (5, -95)]]
    assert presence_ratio(START, at(30), samples, THRESHOLD) == 0.0


def test_threshold_is_strict():
    assert presence_ratio(START, at(30), [(at(1), -75)], THRESHOLD) == 0.0
    assert presence_ratio(START, at(30), [(at(1), -74)], THRESHOLD) == 1.0


def test_samples_outside_session_are_ignored():
    samples = [(at(-5), -50), (at(90), -50), (at(500), -50)]
    assert presence_ratio(START, at(90), samples, THRESHOLD) == 0.0


def test_no_samples_gives_zero():
    assert presence_ratio(START, at(300), [], THRESHOLD) == 0.0


def test_ratio_never_exceeds_one():
    samples = [(at(w * 30 + 1), -50) for w in range(3)]
    assert presence_ratio(START, at(90), samples, THRESHOLD) == 1.0


def test_first_seen_ignores_weak_and_out_of_session_samples():
    samples = [(at(-10), -50), (at(5), -95), (at(40), -60), (at(70), -60)]
    assert first_seen_at(samples, START, at(90), THRESHOLD) == at(40)


def test_first_seen_none_without_valid_samples():
    assert first_seen_at([(at(5), -95)], START, at(90), THRESHOLD) is None
