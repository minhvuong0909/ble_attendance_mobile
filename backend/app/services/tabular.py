import csv
import io
from dataclasses import dataclass

from openpyxl import load_workbook

from app.core.errors import ApiError

MAX_FILE_BYTES = 2_000_000


@dataclass(frozen=True)
class Table:
    headers: list[str]
    rows: list[tuple[int, dict[str, str]]]  # (số dòng trong file, giá trị theo tên cột)


def _build_table(raw_rows: list[list[str]]) -> Table:
    if not raw_rows:
        return Table(headers=[], rows=[])
    headers = [cell.strip().lower() for cell in raw_rows[0]]
    rows: list[tuple[int, dict[str, str]]] = []
    for index, values in enumerate(raw_rows[1:], start=2):
        cells = [value.strip() for value in values]
        if not any(cells):
            continue
        cells += [""] * (len(headers) - len(cells))
        rows.append((index, dict(zip(headers, cells))))
    return Table(headers=headers, rows=rows)


def _read_csv(content: bytes) -> Table:
    try:
        text = content.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ApiError(422, "file_unreadable", "Không đọc được file, hãy lưu CSV dạng UTF-8") from exc
    first_line = text.splitlines()[0] if text.strip() else ""
    delimiter = ";" if first_line.count(";") > first_line.count(",") else ","
    try:
        raw_rows = [row for row in csv.reader(io.StringIO(text), delimiter=delimiter)]
    except csv.Error as exc:
        raise ApiError(422, "file_unreadable", "File CSV bị lỗi định dạng hoặc có ô quá dài") from exc
    return _build_table(raw_rows)


def _read_xlsx(content: bytes) -> Table:
    try:
        workbook = load_workbook(io.BytesIO(content), read_only=True, data_only=True)
        sheet = workbook.active
        raw_rows = [
            ["" if value is None else str(value) for value in row] for row in sheet.iter_rows(values_only=True)
        ]
    except Exception as exc:  # openpyxl ném nhiều loại lỗi tùy kiểu hỏng của file
        raise ApiError(422, "file_unreadable", "Không đọc được file Excel") from exc
    return _build_table(raw_rows)


def read_rows(filename: str, content: bytes) -> Table:
    if len(content) > MAX_FILE_BYTES:
        raise ApiError(413, "file_too_large", "File quá lớn (tối đa 2 MB)")
    extension = filename.lower().rsplit(".", 1)[-1] if "." in filename else ""
    if extension == "csv":
        return _read_csv(content)
    if extension == "xlsx":
        return _read_xlsx(content)
    raise ApiError(422, "unsupported_file", "Chỉ hỗ trợ file .csv hoặc .xlsx")


def require_columns(table: Table, required: list[str]) -> None:
    missing = [column for column in required if column not in table.headers]
    if missing:
        raise ApiError(422, "missing_columns", f"Thiếu cột: {', '.join(missing)}")
