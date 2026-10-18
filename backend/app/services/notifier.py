from sqlalchemy.orm import Session

from app.models import Notification


def notify(
    db: Session,
    user_id: str,
    type: str,
    title: str,
    body: str,
    ref_id: str | None = None,
) -> Notification:
    """Thêm một thông báo vào phiên hiện tại. Người gọi chịu trách nhiệm commit."""
    notification = Notification(
        user_id=user_id, type=type, title=title, body=body, ref_id=ref_id, is_read=False
    )
    db.add(notification)
    return notification


def notify_many(
    db: Session,
    user_ids: list[str],
    type: str,
    title: str,
    body: str,
    ref_id: str | None = None,
) -> None:
    for user_id in user_ids:
        notify(db, user_id, type, title, body, ref_id)
