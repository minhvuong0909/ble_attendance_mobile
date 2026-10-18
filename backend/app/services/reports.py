import re
from io import BytesIO

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.clock import to_local
from app.models import Attendance, AttendanceStatus, ClassRoom, LectureSession
from app.schemas.reports import ClassReportOut, ReportSession, ReportStudent
from app.services.attendance import build_records, enrolled_students
from app.services.stats import late_minutes, stats_from_statuses

STATUS_CODE = {
    AttendanceStatus.present: "P",
    AttendanceStatus.absent: "A",
    AttendanceStatus.excused: "E",
}
STATUS_LABEL = {
    AttendanceStatus.present: "Có mặt",
    AttendanceStatus.absent: "Vắng",
    AttendanceStatus.excused: "Có phép",
}
HEADER_FONT = Font(bold=True, color="FFFFFF")
HEADER_FILL = PatternFill(start_color="0B6E4F", end_color="0B6E4F", fill_type="solid")
THIN = Side(style="thin")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)


def safe_filename(*parts: str) -> str:
    cleaned = [re.sub(r"[^A-Za-z0-9_.-]+", "_", part).strip("_") for part in parts if part]
    name = "_".join(part for part in cleaned if part)
    return name or "report"


def ended_sessions(db: Session, class_id: str) -> list[LectureSession]:
    return list(
        db.scalars(
            select(LectureSession)
            .where(LectureSession.class_id == class_id, LectureSession.is_active.is_(False))
            .order_by(LectureSession.starts_at)
        )
    )


def build_class_report(db: Session, cls: ClassRoom) -> ClassReportOut:
    sessions = ended_sessions(db, cls.id)
    session_ids = [s.id for s in sessions]
    rows = {
        (row.session_id, row.student_user_id): row.status
        for row in db.scalars(select(Attendance).where(Attendance.session_id.in_(session_ids)))
    } if session_ids else {}

    students: list[ReportStudent] = []
    for student in enrolled_students(db, cls.id):
        cells = [rows.get((session.id, student.id)) for session in sessions]
        stats = stats_from_statuses([cell for cell in cells if cell is not None], cls.max_absence_percent)
        students.append(
            ReportStudent(
                student_user_id=student.id,
                student_id=student.student_id,
                student_name=student.full_name,
                cells=cells,
                present=stats.present,
                absent=stats.absent,
                excused=stats.excused,
                attendance_percent=stats.attendance_percent,
                absent_percent=stats.absent_percent,
                warning=stats.warning,
            )
        )

    average = round(sum(s.attendance_percent for s in students) / len(students), 1) if students else 100.0
    return ClassReportOut(
        class_id=cls.id,
        course_code=cls.course.code,
        course_name=cls.course.name,
        class_code=cls.class_code,
        semester=cls.semester,
        sessions=[ReportSession(id=s.id, starts_at=s.starts_at) for s in sessions],
        students=students,
        average_attendance_percent=average,
    )


def _header_row(ws, row: int, headers: list[str]) -> None:
    for column, header in enumerate(headers, 1):
        cell = ws.cell(row=row, column=column, value=header)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = Alignment(horizontal="center")
        cell.border = BORDER


def _body_cell(ws, row: int, column: int, value) -> None:
    cell = ws.cell(row=row, column=column, value=value if value != "" else None)
    cell.border = BORDER
    cell.alignment = Alignment(horizontal="center")


def _to_bytes(workbook: Workbook) -> bytes:
    buffer = BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


def class_report_xlsx(report: ClassReportOut) -> bytes:
    workbook = Workbook()
    ws = workbook.active
    ws.title = "Chuyên cần"
    headers = (
        ["STT", "MSSV", "Họ tên"]
        + [to_local(s.starts_at).strftime("%d/%m") for s in report.sessions]
        + ["Có mặt", "Vắng", "Có phép", "% chuyên cần"]
    )
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(headers))
    title = ws["A1"]
    title.value = (
        f"Báo cáo chuyên cần — {report.course_code} {report.course_name} — "
        f"{report.class_code} ({report.semester})"
    )
    title.font = Font(bold=True, size=14)
    title.alignment = Alignment(horizontal="center")
    _header_row(ws, 3, headers)

    for index, student in enumerate(report.students, 1):
        row = 3 + index
        values = (
            [index, student.student_id, student.student_name]
            + [STATUS_CODE[cell] if cell is not None else None for cell in student.cells]
            + [student.present, student.absent, student.excused, student.attendance_percent]
        )
        for column, value in enumerate(values, 1):
            _body_cell(ws, row, column, value)

    ws.column_dimensions["B"].width = 14
    ws.column_dimensions["C"].width = 26
    return _to_bytes(workbook)


def session_report_xlsx(db: Session, session: LectureSession) -> bytes:
    cls = db.get(ClassRoom, session.class_id)
    workbook = Workbook()
    ws = workbook.active
    ws.title = "Buổi học"
    headers = [
        "STT", "MSSV", "Họ tên", "Số lần phát hiện", "% hiện diện", "Trạng thái",
        "Đã chốt", "Giờ đến", "Trễ (phút)", "Lý do chỉnh tay",
    ]
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(headers))
    ws["A1"].value = f"Điểm danh — {cls.course.code} {cls.class_code} — {to_local(session.starts_at):%d/%m/%Y %H:%M}"
    ws["A1"].font = Font(bold=True, size=14)
    ws["A1"].alignment = Alignment(horizontal="center")
    _header_row(ws, 3, headers)

    for index, record in enumerate(build_records(db, session), 1):
        values = [
            index,
            record.student_id,
            record.student_name,
            record.detection_count,
            round(record.presence_ratio * 100, 1),
            STATUS_LABEL[record.status],
            "Có" if record.finalized else "Không",
            f"{to_local(record.first_seen_at):%H:%M}" if record.first_seen_at else None,
            late_minutes(session.starts_at, record.first_seen_at),
            record.override_reason,
        ]
        for column, value in enumerate(values, 1):
            _body_cell(ws, 3 + index, column, value)

    ws.column_dimensions["B"].width = 14
    ws.column_dimensions["C"].width = 26
    return _to_bytes(workbook)
