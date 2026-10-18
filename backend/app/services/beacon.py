import hashlib
import hmac
from datetime import datetime, timezone

from app.core.config import settings

BUCKET_SECONDS = 30
TAG_LENGTH = 8


def bucket_of(moment: datetime) -> int:
    aware = moment.replace(tzinfo=timezone.utc) if moment.tzinfo is None else moment
    return int(aware.timestamp() // BUCKET_SECONDS)


def student_secret(session_id: str, student_id: str) -> str:
    return hmac.new(
        settings.beacon_server_key.encode(),
        f"{session_id}:{student_id}".encode(),
        hashlib.sha256,
    ).hexdigest()


def make_tag(secret: str, bucket: int) -> str:
    digest = hmac.new(secret.encode(), str(bucket).encode(), hashlib.sha256).hexdigest()
    return digest[:TAG_LENGTH]


def verify_tag(secret: str, bucket: int, tag: str, observed_at: datetime) -> bool:
    if abs(bucket - bucket_of(observed_at)) > 1:
        return False
    return hmac.compare_digest(make_tag(secret, bucket), tag.lower())
