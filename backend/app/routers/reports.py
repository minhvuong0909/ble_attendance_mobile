from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.core.clock import to_local
from app.core.database import get_db
from app.core.security import require_roles
from app.models import ClassRoom, User, UserRole
from app.schemas.reports import ClassReportOut
from app.services.access import (
    get_class_or_404,
    get_session_or_404,
    require_class_access,
    require_session_class_teacher,
)
from app.services.reports import (
    build_class_report,
    class_report_xlsx,
    safe_filename,
    session_report_xlsx,
)

router = APIRouter(tags=["reports"])

XLSX_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
STAFF = require_roles(UserRole.teacher, UserRole.admin)


def _xlsx_response(content: bytes, filename: str) -> Response:
    return Response(
        content=content,
        media_type=XLSX_TYPE,
        headers={"Content-Disposition": f'attachment; filename="{filename}.xlsx"'},
    )


@router.get("/classes/{class_id}/report", response_model=ClassReportOut)
def class_report(
    class_id: str, db: Session = Depends(get_db), user: User = Depends(STAFF)
) -> ClassReportOut:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    return build_class_report(db, cls)


@router.get("/classes/{class_id}/report/export")
def class_report_export(
    class_id: str, db: Session = Depends(get_db), user: User = Depends(STAFF)
) -> Response:
    cls = get_class_or_404(db, class_id)
    require_class_access(db, user, cls)
    report = build_class_report(db, cls)
    filename = safe_filename("attendance", cls.course.code, cls.class_code, cls.semester)
    return _xlsx_response(class_report_xlsx(report), filename)


@router.get("/sessions/{session_id}/export")
def session_export(
    session_id: str, db: Session = Depends(get_db), user: User = Depends(STAFF)
) -> Response:
    session = get_session_or_404(db, session_id)
    if user.role == UserRole.teacher:
        require_session_class_teacher(db, user, session)
    cls = db.get(ClassRoom, session.class_id)
    filename = safe_filename(
        "attendance", cls.course.code, cls.class_code, f"{to_local(session.starts_at):%Y%m%d}"
    )
    return _xlsx_response(session_report_xlsx(db, session), filename)
