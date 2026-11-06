import time
from collections import defaultdict, deque
from collections.abc import Callable


class FailureLimiter:
    """Giới hạn số lần thất bại trong một khoảng thời gian (bộ nhớ tiến trình, đủ cho một máy chủ)."""

    def __init__(self, max_failures: int, window_seconds: float, now: Callable[[], float] = time.monotonic) -> None:
        self.max_failures = max_failures
        self.window = window_seconds
        self._now = now
        self._failures: dict[str, deque[float]] = defaultdict(deque)

    def _prune(self, key: str) -> deque[float]:
        events = self._failures[key]
        cutoff = self._now() - self.window
        while events and events[0] <= cutoff:
            events.popleft()
        if not events:
            self._failures.pop(key, None)
            return deque()
        return events

    def blocked(self, key: str) -> bool:
        return len(self._prune(key)) >= self.max_failures

    def record(self, key: str) -> None:
        self._prune(key)
        self._failures[key].append(self._now())

    def reset(self, key: str | None = None) -> None:
        if key is None:
            self._failures.clear()
        else:
            self._failures.pop(key, None)


# Mỗi mã đăng nhập tối đa 5 lần sai / 5 phút; mỗi IP tối đa 30 lần sai / 5 phút.
login_by_identifier = FailureLimiter(5, 300)
login_by_ip = FailureLimiter(30, 300)
