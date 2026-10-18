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
