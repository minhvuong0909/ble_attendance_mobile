# Hệ thống điểm danh bằng BLE

Đây là bản mẫu hệ thống điểm danh lớp học bằng Bluetooth Low Energy (BLE) và xác thực trên thiết bị.

## Công nghệ

- Ứng dụng Flutter dùng chung cho giảng viên và sinh viên
- Backend FastAPI
- Cơ sở dữ liệu PostgreSQL chạy bằng Docker Compose

## Cấu trúc

- `backend/`: API, model dữ liệu và script tạo dữ liệu mẫu
- `mobile/ble_attendance_mobile/`: ứng dụng Flutter
- `ARCHITECTURE.md`: kiến trúc và phạm vi bản mẫu

## Chức năng

- Đăng ký, đăng nhập và phân quyền
- Tạo, mở chốt và kết thúc buổi học
- Phát và quét beacon BLE giữa thiết bị giảng viên và sinh viên
- Ghi nhận RSSI và gửi detection lên backend
- Chốt điểm danh bằng xác thực trên thiết bị
- Xem tổng kết, điều chỉnh thủ công và xuất Excel

## Tài khoản mẫu

- Giảng viên: `T001` / `Pass@123`
- Sinh viên: `25CE099` / `Pass@123`
- Sinh viên: `25CE100` / `Pass@123`
- Sinh viên: `D26CE045` / `Pass@123`

## Chạy trên Windows

```powershell
cd backend
docker compose up -d
cd ..
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r backend\requirements.txt
$env:PYTHONPATH="backend"
python backend\scripts\seed_demo.py
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --app-dir backend
```

Tài liệu API: `http://127.0.0.1:8000/docs`

Chạy Flutter trên điện thoại cùng mạng Wi-Fi:

```powershell
cd mobile\ble_attendance_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.7:8000
```

Thay địa chỉ IP bằng IPv4 của máy chạy backend.

## Lưu ý

- Đây là bản mẫu học tập, chưa phù hợp triển khai production.
- RSSI chỉ ước lượng độ gần, không đo khoảng cách chính xác.
- Trên iOS, cần giữ ứng dụng hoạt động trong buổi học.
- Khi triển khai thật, phải thay JWT secret, bật HTTPS và cấu hình khóa ký release.
