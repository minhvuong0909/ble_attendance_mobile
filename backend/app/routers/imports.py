from fastapi import APIRouter, Depends, File, Response, UploadFile
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ApiError
from app.core.security import require_roles
from app.models import UserRole
from app.schemas.imports import ImportReportOut
from app.services.access import get_class_or_404
from app.services.importer import classes_runner, run_import, students_runner, teachers_runner
from app.services.tabular import read_rows

router = APIRouter(
    prefix="/admin",
    tags=["admin-import"],
    dependencies=[Depends(require_roles(UserRole.admin))],
)

TEMPLATES = {
    "students": "student_id,full_name\n25CE099,Nguyen Van A\n",
    "teachers": "teacher_id,full_name\nT002,Tran Van B\n",
    "classes": "course_code,course_name,class_code,semester,teacher_id\nPRM393,Lap trinh di dong,SE1901,FA26,T001\n",
}


@router.post("/classes/{class_id}/import-students", response_model=ImportReportOut)
def import_class_students(
    class_id: str,
    file: UploadFile = File(...),
    dry_run: bool = False,
    db: Session = Depends(get_db),
) -> ImportReportOut:
    cls = get_class_or_404(db, class_id)
    table = read_rows(file.filename or "", file.file.read())
    return run_import(db, "students", students_runner(cls), table, dry_run)


@router.post("/imports/teachers", response_model=ImportReportOut)
def import_teachers(
    file: UploadFile = File(...), dry_run: bool = False, db: Session = Depends(get_db)
) -> ImportReportOut:
    table = read_rows(file.filename or "", file.file.read())
    return run_import(db, "teachers", teachers_runner(), table, dry_run)


@router.post("/imports/classes", response_model=ImportReportOut)
def import_classes(
    file: UploadFile = File(...), dry_run: bool = False, db: Session = Depends(get_db)
) -> ImportReportOut:
    table = read_rows(file.filename or "", file.file.read())
    return run_import(db, "classes", classes_runner(), table, dry_run)


@router.get("/imports/templates/{kind}")
def download_template(kind: str) -> Response:
    if kind not in TEMPLATES:
        raise ApiError(404, "template_not_found", "Không có file mẫu này")
    return Response(
        content="﻿" + TEMPLATES[kind],
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{kind}_template.csv"'},
    )
