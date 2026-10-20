from collections.abc import Callable

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.core.validators import is_valid_student_id, normalize_id
from app.models import ClassRoom, Course, Enrollment, User, UserRole
from app.schemas.imports import ImportReportOut, ImportRowOut
from app.services.academic import new_join_code
from app.services.accounts import login_id_taken
from app.services.access import is_enrolled
from app.services.tabular import Table, require_columns

Runner = Callable[[Session, Table, bool], list[ImportRowOut]]

# Giới hạn độ dài khớp với cột trong database.
MAX_NAME = 120
MAX_CODE = 32


def _row(number: int, status: str, message: str) -> ImportRowOut:
    return ImportRowOut(row=number, status=status, message=message)


def _new_account(ident: str, name: str, role: UserRole) -> User:
    ids = {"student_id": ident} if role == UserRole.student else {"teacher_id": ident}
    return User(
        full_name=name,
        role=role,
        password_hash=hash_password(ident),
        must_change_password=True,
        **ids,
    )


def students_runner(cls: ClassRoom) -> Runner:
    def run(db: Session, table: Table, apply: bool) -> list[ImportRowOut]:
        require_columns(table, ["student_id", "full_name"])
        seen: set[str] = set()
        results: list[ImportRowOut] = []
        for number, data in table.rows:
            ident = normalize_id(data["student_id"])
            name = data["full_name"].strip()
            if not is_valid_student_id(ident):
                results.append(_row(number, "error", "Mã sinh viên không hợp lệ"))
                continue
            if len(name) < 2:
                results.append(_row(number, "error", "Thiếu họ tên"))
                continue
            if len(name) > MAX_NAME:
                results.append(_row(number, "error", f"Họ tên quá dài (tối đa {MAX_NAME} ký tự)"))
                continue
            if ident in seen:
                results.append(_row(number, "error", "Mã sinh viên bị trùng trong file"))
                continue
            seen.add(ident)

            user = db.scalar(select(User).where(User.student_id == ident))
            if user is None and login_id_taken(db, ident):
                results.append(_row(number, "error", "Mã này đang thuộc một tài khoản khác"))
                continue
            if user is not None and is_enrolled(db, cls.id, user.id):
                results.append(_row(number, "skipped", "Đã ở trong lớp"))
                continue

            message = "Thêm vào lớp"
            if user is None:
                message = "Tạo tài khoản và thêm vào lớp"
                if apply:
                    user = _new_account(ident, name, UserRole.student)
                    db.add(user)
                    db.flush()
            if apply:
                db.add(Enrollment(class_id=cls.id, student_user_id=user.id, source="import"))
            results.append(_row(number, "created", message))
        return results

    return run


def teachers_runner() -> Runner:
    def run(db: Session, table: Table, apply: bool) -> list[ImportRowOut]:
        require_columns(table, ["teacher_id", "full_name"])
        seen: set[str] = set()
        results: list[ImportRowOut] = []
        for number, data in table.rows:
            ident = normalize_id(data["teacher_id"])
            name = data["full_name"].strip()
            if not 3 <= len(ident) <= 16:
                results.append(_row(number, "error", "Mã giảng viên phải dài từ 3 đến 16 ký tự"))
                continue
            if len(name) < 2:
                results.append(_row(number, "error", "Thiếu họ tên"))
                continue
            if len(name) > MAX_NAME:
                results.append(_row(number, "error", f"Họ tên quá dài (tối đa {MAX_NAME} ký tự)"))
                continue
            if ident in seen:
                results.append(_row(number, "error", "Mã giảng viên bị trùng trong file"))
                continue
            seen.add(ident)

            existing = db.scalar(select(User).where(User.teacher_id == ident))
            if existing is not None:
                if existing.role == UserRole.teacher:
                    results.append(_row(number, "skipped", "Giảng viên đã tồn tại"))
                else:
                    results.append(_row(number, "error", "Mã này đang thuộc một tài khoản khác"))
                continue
            if login_id_taken(db, ident):
                results.append(_row(number, "error", "Mã này đang thuộc một tài khoản khác"))
                continue
            if apply:
                db.add(_new_account(ident, name, UserRole.teacher))
                db.flush()
            results.append(_row(number, "created", "Tạo tài khoản giảng viên"))
        return results

    return run


def classes_runner() -> Runner:
    def run(db: Session, table: Table, apply: bool) -> list[ImportRowOut]:
        require_columns(table, ["course_code", "course_name", "class_code", "semester"])
        seen: set[tuple[str, str, str]] = set()
        new_courses: set[str] = set()
        results: list[ImportRowOut] = []
        for number, data in table.rows:
            course_code = data["course_code"].strip().upper()
            course_name = data["course_name"].strip()
            class_code = data["class_code"].strip().upper()
            semester = data["semester"].strip()
            teacher_code = normalize_id(data.get("teacher_id", ""))

            if len(course_code) < 2 or not class_code or len(semester) < 2:
                results.append(_row(number, "error", "Thiếu mã môn, mã lớp hoặc học kỳ"))
                continue
            if max(len(course_code), len(class_code), len(semester)) > MAX_CODE or len(course_name) > MAX_NAME:
                results.append(
                    _row(number, "error", f"Mã/học kỳ tối đa {MAX_CODE} ký tự, tên môn tối đa {MAX_NAME} ký tự")
                )
                continue
            key = (course_code, class_code, semester)
            if key in seen:
                results.append(_row(number, "error", "Lớp bị trùng trong file"))
                continue

            teacher = None
            if teacher_code:
                teacher = db.scalar(
                    select(User).where(User.teacher_id == teacher_code, User.role == UserRole.teacher)
                )
                if teacher is None:
                    results.append(_row(number, "error", f"Không tìm thấy giảng viên {teacher_code}"))
                    continue

            course = db.scalar(select(Course).where(Course.code == course_code))
            course_is_new = course is None and course_code not in new_courses
            if course_is_new and len(course_name) < 2:
                results.append(_row(number, "error", "Môn học mới cần có tên môn"))
                continue
            seen.add(key)

            if course is not None:
                exists = db.scalar(
                    select(ClassRoom.id).where(
                        ClassRoom.course_id == course.id,
                        ClassRoom.class_code == class_code,
                        ClassRoom.semester == semester,
                    )
                )
                if exists is not None:
                    results.append(_row(number, "skipped", "Lớp đã tồn tại"))
                    continue

            if course_is_new:
                new_courses.add(course_code)
                if apply:
                    course = Course(code=course_code, name=course_name)
                    db.add(course)
                    db.flush()
            if apply:
                db.add(
                    ClassRoom(
                        course_id=course.id,
                        class_code=class_code,
                        semester=semester,
                        teacher_user_id=teacher.id if teacher else None,
                        join_code=new_join_code(db),
                    )
                )
                db.flush()
            results.append(_row(number, "created", "Tạo lớp mới" + (" và môn học mới" if course_is_new else "")))
        return results

    return run


def run_import(db: Session, kind: str, runner: Runner, table: Table, dry_run: bool) -> ImportReportOut:
    """Chạy thử trước; chỉ ghi thật khi không có dòng lỗi nào."""
    rows = runner(db, table, False)
    by_number = dict(table.rows)
    for r in rows:
        r.data = dict(by_number.get(r.row, {}))  # dữ liệu gốc của dòng, để xem trước đối chiếu
    errors = sum(1 for r in rows if r.status == "error")
    committed = False
    if not dry_run and errors == 0:
        rows = runner(db, table, True)
        for r in rows:
            r.data = dict(by_number.get(r.row, {}))
        db.commit()
        committed = True
    return ImportReportOut(
        kind=kind,
        dry_run=dry_run,
        committed=committed,
        total=len(rows),
        created=sum(1 for r in rows if r.status == "created"),
        skipped=sum(1 for r in rows if r.status == "skipped"),
        errors=errors,
        rows=rows,
    )
