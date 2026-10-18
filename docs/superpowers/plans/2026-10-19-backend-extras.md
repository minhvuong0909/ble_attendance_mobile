# Backend Extras Implementation Plan (Plan 2/5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (the human chose inline/native execution). Steps use checkbox syntax. Every task is TDD: write the tests listed, watch them fail, then implement.

**Goal:** Hoàn thiện phần còn lại của backend theo spec: thông báo in-app, thống kê chuyên cần cho SV, báo cáo/Excel cho GV, xin phép vắng, import CSV/Excel cho Admin.

**Architecture:** Tiếp nối Plan 1 (`docs/superpowers/plans/2026-10-18-backend-core.md`, đã merge): router mỏng, logic trong `app/services/`, lỗi `ApiError {detail, code}`, thời gian naive UTC, JSON trả `UtcDateTime` (hậu tố `Z`). Bảng `leave_requests`, `notifications` đã có trong migration `0001`, nên **không cần migration mới**.

**Tech Stack:** FastAPI, SQLAlchemy 2, openpyxl (đã có), `python-multipart` (mới, cho upload file), pytest.

**Spec:** `docs/superpowers/specs/2026-10-18-ble-attendance-expansion-design.md` (mục 4.5, 6.2, 6.3, 6.4)

**Ghi chú về định dạng plan (Ruling):** plan này gọn hơn Plan 1 — mỗi task nêu file, interface, hành vi và danh sách test cần có; mã test và mã cài đặt được viết trong lúc thực thi theo TDD. Lý do: người dùng yêu cầu làm tiếp ngay, spec đã được duyệt, và Plan 1 đã chốt mọi quy ước. Chi phí nếu sai: phải sửa lại khi thực thi (đã ghi vào ledger).

## Global Constraints

- Quy ước của Plan 1 giữ nguyên: Python 3.12, venv `backend/.venv`, `utcnow()` naive UTC, `normalize_id`, lỗi `ApiError(status, code, detail)`, `require_roles(...)`, 404 khi truy cập lớp/buổi không thuộc quyền.
- Chuyên cần của SV trong một lớp = `(present + excused) / tổng số buổi đã kết thúc mà SV có bản ghi attendance`; `absent_percent = absent / tổng * 100`; **cảnh báo khi `absent_percent > classes.max_absence_percent`** (so sánh nghiêm ngặt). Tổng = 0 thì `attendance_percent = 100.0`, `absent_percent = 0.0`, không cảnh báo.
- Chỉ tính buổi `is_active = false`.
- "Trễ X phút" = `floor((first_seen_at - starts_at) / 60s)` (không âm), chỉ có khi `first_seen_at` có giá trị.
- Import: CSV (UTF-8, chấp nhận BOM) hoặc XLSX; tối đa 2 000 000 byte; cột phân biệt hoa thường sau `strip().lower()`; **không dừng ở lỗi đầu tiên**; chỉ ghi thật khi **không có dòng lỗi** (ngược lại trả `committed=false`); `dry_run=true` không ghi gì; mặc định `dry_run=false`.
- Tài khoản tạo bởi import: mật khẩu tạm = mã định danh viết hoa, `must_change_password=true`.
- Xin phép: mỗi `(student, class, date)` chỉ một đơn đang `pending` hoặc `approved`; SV phải thuộc lớp; chỉ GV hiện tại của lớp được duyệt; đơn đã duyệt/từ chối không duyệt lại.
- Khi duyệt `approved`, các buổi đã kết thúc của lớp trong cùng ngày địa phương mà SV đang `absent` và **chưa bị override** chuyển thành `excused`.
- Thông báo: tạo cùng transaction với hành động gây ra nó; không gửi thông báo trùng khi hành động lặp lại (idempotent).
- Tên file Excel chỉ chứa `[A-Za-z0-9_.-]`.
- Nhánh: `feature/backend-extras`.

## Review Focus

1. Mở chốt hai lần không gửi thông báo hai lần (task 2).
2. SV vào lớp muộn (không có bản ghi cho buổi cũ) không bị tính vắng các buổi đó (task 3).
3. File CSV có BOM hoặc dòng trống/ô thừa khoảng trắng vẫn nhập đúng; file thiếu cột trả 422 rõ ràng (task 6).
4. Duyệt đơn xin phép không ghi đè kết quả GV đã override (task 5).
5. Mã SV trùng trong cùng một file import chỉ được tính một lần, dòng sau báo lỗi (task 6).

## File Structure

```
backend/app/
├── schemas/{common,notifications,stats,reports,leave,imports}.py   (common.py đã có)
├── routers/{notifications,me,reports,leave,imports}.py
└── services/{notifier,stats,reports,leave,tabular,importer}.py
backend/tests/test_{notifications,stats,reports,leave,import}.py
```

---

### Task 1: Dịch vụ thông báo và API thông báo

**Files:** Create `services/notifier.py`, `schemas/notifications.py`, `routers/notifications.py`; modify `main.py`; test `tests/test_notifications.py`.

**Interfaces:**
- Produces: `notify(db, user_id: str, type: str, title: str, body: str, ref_id: str | None = None) -> Notification` (chỉ `db.add`, không commit), `notify_many(db, user_ids: list[str], …) -> None`.
- Endpoint (mọi role đã đăng nhập, chỉ thấy thông báo của mình): `GET /notifications?unread_only=false&limit=50` (mới nhất trước, `limit` 1–200), `GET /notifications/unread-count` → `{"count": int}`, `POST /notifications/{id}/read` (404 nếu không phải của mình), `POST /notifications/read-all` → `{"updated": int}`.
- `NotificationOut(id, type, title, body, ref_id, is_read, created_at: UtcDateTime)`.

**Tests:** list chỉ trả của mình và sắp xếp mới nhất trước; `unread_only`; `limit` ngoài khoảng → 422; unread-count; đánh dấu đã đọc giảm count; không đọc được thông báo người khác (404); read-all trả đúng số; chưa đăng nhập → 401.

### Task 2: Thống kê chuyên cần và `/me`

**Files:** Create `services/stats.py`, `schemas/stats.py`, `routers/me.py`; modify `main.py`; test `tests/test_stats.py`.

**Interfaces:**
- Produces: `ClassStats` dataclass (`total, present, absent, excused, attendance_percent, absent_percent, warning`) và `class_stats(db, cls: ClassRoom, student_user_id: str) -> ClassStats`; `late_minutes(starts_at, first_seen_at) -> int | None`.
- Endpoint (chỉ student): `GET /me/attendance?class_id=` → danh sách `{session_id, starts_at, ends_at, status, presence_ratio, first_seen_at, late_minutes}` (buổi đã kết thúc, mới nhất trước; `class_id` bắt buộc, SV phải thuộc lớp, ngược lại 404); `GET /me/attendance/stats` → danh sách theo lớp đã vào: `{class_id, course_code, course_name, class_code, semester, total_sessions, present, absent, excused, attendance_percent, absent_percent, max_absence_percent, warning}`.

**Tests:** công thức với (3 present, 1 absent, 1 excused → 80%/20%); biên cảnh báo (`absent_percent == max` không cảnh báo, lớn hơn thì cảnh báo); lớp chưa có buổi → 100.0, không cảnh báo; buổi đang diễn ra không được tính; SV vào lớp muộn (không có bản ghi) không bị tính vắng; `late_minutes` (0 khi vừa đúng giờ, 3 khi 3 phút 59 giây, `None` khi không có `first_seen_at`); `/me/attendance` thiếu `class_id` → 422, lớp không thuộc SV → 404; teacher gọi `/me/...` → 403.

### Task 3: Sự kiện thông báo: mở chốt và cảnh báo vắng

**Files:** Modify `routers/sessions.py` (`open_finalization`), `services/attendance.py` (`close_session`); tests append to `tests/test_notifications.py`.

**Behavior:**
- Lần **đầu** GV mở chốt (`finalization_open` chuyển False → True): `notify_many` cho mọi SV của lớp, `type="finalization_open"`, `ref_id=session.id`. Gọi lại khi đã mở: không thêm thông báo.
- Trong `close_session` (chỉ khi thực sự đóng, `rowcount == 1`): với mỗi SV **vắng buổi này** (`status == absent`) mà `class_stats(...).warning` là True → `notify(..., type="absence_warning", ref_id=cls.id)`.

**Tests:** mở chốt → mỗi SV trong lớp có đúng 1 thông báo, SV ngoài lớp không có; mở chốt lần hai không thêm; kết thúc buổi: SV vắng vượt ngưỡng nhận cảnh báo, SV vắng chưa vượt ngưỡng thì không, SV có mặt không; kết thúc hai lần không cảnh báo hai lần.

### Task 4: Báo cáo lớp và xuất Excel

**Files:** Create `services/reports.py`, `schemas/reports.py`, `routers/reports.py`; modify `main.py`; test `tests/test_reports.py`.

**Interfaces:**
- Produces: `build_class_report(db, cls) -> ClassReportOut`, `class_report_xlsx(report, cls) -> bytes`, `session_report_xlsx(db, session) -> bytes`, `safe_filename(*parts) -> str`.
- `ClassReportOut(class_id, course_code, course_name, class_code, semester, sessions: [ {id, starts_at} ] (cũ → mới), students: [ {student_user_id, student_id, student_name, cells: [status|None], present, absent, excused, attendance_percent, absent_percent, warning} ], average_attendance_percent)`; `cells` cùng thứ tự `sessions`, `None` nếu SV không có bản ghi buổi đó; SV sắp theo mã SV; lớp không có SV → `average_attendance_percent = 100.0`.
- Endpoint (teacher hiện tại của lớp hoặc admin; SV → 403; GV khác → 404): `GET /classes/{id}/report`, `GET /classes/{id}/report/export` (xlsx), `GET /sessions/{id}/export` (xlsx, quyền theo lớp của buổi).
- Excel lớp: tiêu đề, dòng ngày (giờ địa phương `dd/MM`), mỗi ô `P`/`A`/`E`/trống, cột tổng Có mặt/Vắng/Có phép/% chuyên cần. Excel buổi: STT, MSSV, Họ tên, Số lần phát hiện, % hiện diện, Trạng thái, Đã chốt, Giờ đến (giờ địa phương), Trễ (phút), Lý do chỉnh tay.

**Tests:** ma trận đúng thứ tự và ô trống; tổng và % từng SV; trung bình lớp; quyền truy cập 4 vai trò; file xlsx mở lại được bằng openpyxl và có đúng tiêu đề/số dòng/giá trị ô; `Content-Disposition` có tên file an toàn khi mã lớp chứa ký tự lạ; `safe_filename("PRM 393", "Học kỳ")` chỉ còn ký tự cho phép.

### Task 5: Xin phép vắng

**Files:** Create `services/leave.py`, `schemas/leave.py`, `routers/leave.py`; modify `main.py`; test `tests/test_leave.py`.

**Interfaces:**
- Produces: `apply_leave_to_settled_sessions(db, leave: LeaveRequest) -> int` (số hàng được chuyển sang excused), `leave_to_out(db, leave) -> LeaveOut`.
- `LeaveCreate(class_id, date, reason: 3–500)`, `LeaveReview(decision: "approved"|"rejected", note: str | None ≤ 255)`, `LeaveOut(id, student_user_id, student_id, student_name, class_id, course_code, class_code, date, reason, status, created_at, reviewed_at, review_note)`.
- Endpoint: `POST /leave-requests` (student → 201, thông báo `leave_submitted` cho GV của lớp nếu có, `ref_id=leave.id` dạng chuỗi), `GET /leave-requests/mine?class_id=` (student), `GET /classes/{id}/leave-requests?status=` (GV hiện tại của lớp hoặc admin), `POST /leave-requests/{id}/review` (GV hiện tại của lớp; 409 `already_reviewed`; thông báo `leave_reviewed` cho SV; `approved` gọi `apply_leave_to_settled_sessions`).

**Tests:** tạo đơn thành công + thông báo cho GV; SV ngoài lớp → 404; đơn trùng (cùng lớp/ngày đang pending hoặc approved) → 409 `leave_exists`, nhưng đơn bị `rejected` thì được nộp lại; lý do quá ngắn → 422; duyệt đúng quyền (GV khác → 404, SV → 403); duyệt hai lần → 409; duyệt `approved` chuyển buổi đã kết thúc cùng ngày địa phương từ absent sang excused nhưng **không** đổi hàng đã override và **không** đổi hàng `present`; `rejected` không đổi gì; danh sách lọc theo `status`; SV chỉ thấy đơn của mình.

### Task 6: Import danh sách từ CSV/Excel

**Files:** Create `services/tabular.py`, `services/importer.py`, `schemas/imports.py`, `routers/imports.py`; modify `main.py`, `requirements.txt` (thêm `python-multipart==0.0.20`); test `tests/test_import.py`.

**Interfaces:**
- Produces: `read_rows(filename: str, content: bytes) -> list[tuple[int, dict[str, str]]]` (số dòng bắt đầu từ 2, bỏ dòng trống hoàn toàn; ném `ApiError` 422 `unsupported_file`/`file_unreadable`, 413 `file_too_large`), `require_columns(rows, required) -> None` (422 `missing_columns`), `import_students(db, cls, rows, apply) -> ImportReportOut`, `import_teachers(db, rows, apply)`, `import_classes(db, rows, apply)`.
- `ImportReportOut(kind, dry_run, committed, total, created, skipped, errors, rows: [ {row, status: "created"|"skipped"|"error", message} ])`.
- Endpoint (admin): `POST /admin/classes/{id}/import-students`, `POST /admin/imports/teachers`, `POST /admin/imports/classes` (multipart field `file`, query `dry_run`), `GET /admin/imports/templates/{kind}` (`students|teachers|classes` → CSV có BOM, header + 1 dòng mẫu; kind lạ → 404).
- Cột: students `student_id, full_name`; teachers `teacher_id, full_name`; classes `course_code, course_name, class_code, semester, teacher_id` (cột cuối tùy chọn).
- Quy tắc từng dòng: students — mã sai định dạng → error; trùng trong file → error "trùng trong file"; mã đã là tài khoản GV → error; SV đã tồn tại thì dùng lại (không tạo mới); đã ở trong lớp → skipped; ngược lại tạo tài khoản (nếu cần) và `Enrollment(source="import")` → created. teachers — mã đã tồn tại (GV) → skipped; trùng mã SV → error. classes — tạo môn nếu chưa có (cần `course_name`); lớp đã tồn tại → skipped; `teacher_id` không phải GV → error; tạo lớp mới có `join_code`.
- Ghi thật chỉ khi `errors == 0`; nếu không `committed=false` và không thay đổi gì.

**Tests:** CSV hợp lệ (có BOM, khoảng trắng, dòng trống) tạo tài khoản + ghi danh đúng và đăng nhập được bằng mật khẩu tạm; XLSX tương đương; `dry_run=true` không ghi gì nhưng báo đúng số liệu; có dòng lỗi → `committed=false` và DB không đổi; mã SV trùng trong file → dòng sau lỗi; SV đã ở trong lớp → skipped; thiếu cột → 422 `missing_columns`; phần mở rộng lạ → 422; file > 2 000 000 byte → 413; quyền (GV/SV → 403); import teachers và classes (gồm gán GV và tạo môn mới); lớp không tồn tại → 404; template tải về có header đúng.

### Task 7: Tài liệu và kiểm tra tổng

**Files:** Modify `backend/README.md`; (không code mới).

- [ ] Liệt kê toàn bộ endpoint mới trong README (nhóm theo module), ghi quy ước import/Excel.
- [ ] Chạy toàn bộ test; chạy thử trên Postgres thật: `alembic upgrade head`, seed, gọi `/auth/login`, `/notifications/unread-count`, `/admin/imports/templates/students`.
- [ ] Commit.

---

## Self-Review

- **Phủ spec:** 4.5 chuyên cần (task 2), 6.2 thống kê SV / báo cáo / xin phép / thông báo (task 1–5), 6.3 import (task 6), 6.4 sự kiện thông báo (task 3 và 5), `excused` từ đơn đã duyệt (task 5, đồng bộ với 4.2). Hoàn tất danh sách endpoint spec 6.2 sau plan này.
- **Quét placeholder:** không có "TBD"; hành vi, ngưỡng và danh sách test đã nêu cụ thể.
- **Nhất quán tên:** `class_stats`, `late_minutes`, `notify`/`notify_many`, `apply_leave_to_settled_sessions`, `ImportReportOut` được dùng thống nhất giữa các task.
