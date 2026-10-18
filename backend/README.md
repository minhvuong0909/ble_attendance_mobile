# Backend hệ thống điểm danh BLE

Backend FastAPI quản lý tài khoản (admin, giảng viên, sinh viên), môn/lớp, buổi học, detection BLE và kết quả điểm danh trong PostgreSQL.

## Chạy cục bộ (Linux/macOS)

```bash
cd backend
docker compose up -d
python3 -m venv .venv          # hoặc: uv venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt   # hoặc: uv pip install -r requirements-dev.txt
cp .env.example .env
alembic upgrade head
python scripts/seed_demo.py
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Swagger: `http://127.0.0.1:8000/docs`

## Kiểm thử

```bash
pytest -q
```

## Tài khoản demo (mật khẩu `Pass@123`)

- Admin: `A001` · Giảng viên: `T001` · Sinh viên: `25CE099`, `25CE100`, `D26CE045`

## Thay đổi schema

Tạo migration bằng `alembic revision --autogenerate -m "mô tả"` rồi `alembic upgrade head`.
Không còn tự `ALTER TABLE` khi khởi động.

## Bảo mật

Trước khi triển khai thật, phải thay `JWT_SECRET` và `BEACON_SERVER_KEY`, dùng HTTPS, bổ sung rate limit.

## Quy ước thời gian

Mọi thời điểm trả ra JSON là UTC kèm hậu tố `Z` (ví dụ `2026-10-18T03:00:00.123456Z`). Thời điểm gửi lên (`observed_at`) bắt buộc kèm múi giờ; giá trị không có múi giờ bị từ chối với 422.

## Danh sách API

| Nhóm | Endpoint |
|---|---|
| Xác thực | `POST /auth/register` (SV), `POST /auth/login`, `GET /auth/me`, `POST /auth/change-password` |
| Admin | `/admin/courses`, `/admin/classes`, `POST /admin/classes/{id}/assign-teacher`, `/admin/teachers`, `POST /admin/users/{id}/reset-password` |
| Import (admin) | `POST /admin/classes/{id}/import-students`, `POST /admin/imports/teachers`, `POST /admin/imports/classes`, `GET /admin/imports/templates/{students\|teachers\|classes}` |
| Lớp | `GET /classes/mine`, `POST /classes/join`, `GET /classes/{id}`, `GET /classes/{id}/students` |
| Buổi học | `POST /classes/{id}/sessions`, `GET /classes/{id}/sessions`, `POST /sessions/{id}/end`, `POST /sessions/{id}/open-finalization`, `GET /sessions/active` |
| Điểm danh | `POST /detections/batch`, `POST /attendance/finalize`, `GET /sessions/{id}/attendance`, `POST /sessions/{id}/attendance/override` |
| Sinh viên | `GET /me/attendance?class_id=`, `GET /me/attendance/stats` |
| Báo cáo (GV/admin) | `GET /classes/{id}/report`, `GET /classes/{id}/report/export`, `GET /sessions/{id}/export` |
| Xin phép | `POST /leave-requests`, `GET /leave-requests/mine`, `GET /classes/{id}/leave-requests`, `POST /leave-requests/{id}/review` |
| Thông báo | `GET /notifications`, `GET /notifications/unread-count`, `POST /notifications/{id}/read`, `POST /notifications/read-all` |

## Quy ước import

File `.csv` (UTF-8, có hoặc không có BOM) hoặc `.xlsx`, tối đa 2 MB, dòng tiêu đề là dòng 1. Dùng `?dry_run=true` để xem trước. Chỉ ghi thật khi **không có dòng lỗi**; nếu có lỗi, `committed=false` và không có gì thay đổi. Tài khoản mới có mật khẩu tạm bằng mã định danh và phải đổi mật khẩu khi đăng nhập lần đầu.

## Thông báo tự động

Mở chốt điểm danh (gửi cho SV trong lớp), SV gửi đơn xin phép (gửi GV của lớp), GV duyệt hoặc từ chối đơn (gửi SV), kết thúc buổi mà SV vắng vượt mức cho phép (cảnh báo SV).
