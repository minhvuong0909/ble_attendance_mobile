from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.clock import to_naive_utc, utcnow
from app.core.database import get_db
from app.core.security import require_roles
from app.core.validators import normalize_id
from app.models import Detection, LectureSession, User, UserRole
from app.schemas.detections import DetectionBatchIn, DetectionBatchOut
from app.services.access import is_enrolled
from app.services.beacon import student_secret, verify_tag

router = APIRouter(tags=["detections"])

MAX_OBSERVATION_AGE = timedelta(minutes=10)
MAX_FUTURE_SKEW = timedelta(minutes=1)
MIN_RSSI = -127
MAX_RSSI = 0


@router.post("/detections/batch", response_model=DetectionBatchOut)
def submit_batch(
    payload: DetectionBatchIn,
    db: Session = Depends(get_db),
    teacher: User = Depends(require_roles(UserRole.teacher)),
) -> DetectionBatchOut:
    now = utcnow()
    sessions: dict[str, LectureSession | None] = {}
    recorded = 0
    rejected = 0

    for entry in payload.detections:
        if entry.session_id not in sessions:
            sessions[entry.session_id] = db.get(LectureSession, entry.session_id)
        session = sessions[entry.session_id]
        if session is None or not session.is_active or session.teacher_user_id != teacher.id:
            rejected += 1
            continue

        if not MIN_RSSI <= entry.rssi <= MAX_RSSI:
            rejected += 1
            continue

        observed = to_naive_utc(entry.observed_at)
        if observed < session.starts_at or observed > now + MAX_FUTURE_SKEW or now - observed > MAX_OBSERVATION_AGE:
            rejected += 1
            continue

        student_id = normalize_id(entry.student_identifier)
        student = db.scalar(
            select(User).where(User.student_id == student_id, User.role == UserRole.student)
        )
        if student is None or not is_enrolled(db, session.class_id, student.id):
            rejected += 1
            continue

        secret = student_secret(session.id, student_id)
        if not verify_tag(secret, entry.bucket, entry.tag, observed):
            rejected += 1
            continue

        db.add(
            Detection(
                session_id=session.id,
                student_user_id=student.id,
                rssi=entry.rssi,
                detected_at=observed,
            )
        )
        recorded += 1

    db.commit()
    return DetectionBatchOut(recorded=recorded, rejected=rejected)
