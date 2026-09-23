# Backend hệ thống điểm danh BLE

Backend FastAPI quản lý tài khoản, buổi học, detection BLE và kết quả điểm danh trong PostgreSQL.

## Chạy cục bộ

```powershell
docker compose up -d
cd ..
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r backend\requirements.txt
Copy-Item backend\.env.example backend\.env
$env:PYTHONPATH="backend"
python backend\scripts\seed_demo.py
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --app-dir backend
```

Swagger: `http://127.0.0.1:8000/docs`

## API chính

- `POST /auth/register`, `POST /auth/login`
- `POST /sessions`, `POST /sessions/{session_id}/end`
- `GET /sessions/active`
- `POST /teacher/sessions/{session_id}/open-finalization`
- `POST /detections`, `POST /detections/batch`
- `POST /attendance/finalize`
- `GET /teacher/sessions/{session_id}/attendance-summary`
- `POST /teacher/sessions/{session_id}/attendance/override`
- `GET /teacher/sessions/{session_id}/attendance-export`

## Bảo mật

Trước khi triển khai thật, phải thay `JWT_SECRET`, dùng HTTPS, bổ sung rate limit và quản lý schema bằng migration.
