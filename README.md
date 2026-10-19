# Hệ thống điểm danh bằng BLE

Hệ thống điểm danh lớp học bằng Bluetooth Low Energy cho đồ án môn Lập trình di động (Flutter). Giảng viên mở buổi học, điện thoại giảng viên và sinh viên phát/quét BLE, server xác minh và tính chuyên cần; sinh viên xác nhận bằng vân tay hoặc khóa màn hình ở cuối buổi.

## Thành phần

- `mobile/ble_attendance_mobile/`: ứng dụng Flutter (Android). Cùng mã còn build được ra **web** cho admin/giảng viên (import, xuất Excel).
- `backend/`: FastAPI + SQLAlchemy + Alembic, PostgreSQL chạy bằng Docker Compose.
- `docs/superpowers/`: spec thiết kế, các plan, `STATUS.md` (trạng thái công việc).
- `DEMO.md`: kịch bản demo. `ARCHITECTURE.md`: kiến trúc và quy tắc nghiệp vụ.

## Vai trò

| Vai trò | Làm được |
|---|---|
| Admin | Tạo môn, lớp, giảng viên; gán giảng viên cho lớp; import danh sách (CSV/XLSX có xem trước); đặt lại mật khẩu |
| Giảng viên | Xem lớp được gán; bắt đầu/kết thúc buổi, mở chốt; chỉnh tay điểm danh; báo cáo và xuất Excel; duyệt đơn xin phép |
| Sinh viên | Tham gia lớp bằng mã; điểm danh bằng BLE; xem thống kê chuyên cần; xin phép nghỉ; nhận thông báo |

## Chạy nhanh (Linux/macOS)

```bash
cd backend
docker compose up -d
uv venv .venv && uv pip install -r requirements-dev.txt   # hoặc python3 -m venv
cp .env.example .env
.venv/bin/alembic upgrade head
.venv/bin/python scripts/seed_demo.py
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Swagger: `http://127.0.0.1:8000/docs`. Trên Windows dùng `.\.venv\Scripts\...` tương ứng.

**Bản web** (giao diện desktop cho admin/giảng viên, import/xuất file trên laptop): `backend/scripts/build_web.sh`, rồi mở `http://<IP-máy>:8000/app/`.

**Ứng dụng Android:**

```bash
cd mobile/ble_attendance_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<IP-máy-chạy-backend>:8000
flutter build apk --release --target-platform android-arm,android-arm64
```

Địa chỉ máy chủ cũng đổi được trong app (biểu tượng bánh răng ở màn hình đăng nhập). Điện thoại và máy chủ cùng mạng Wi-Fi; emulator dùng `http://10.0.2.2:8000`.

**Ký APK release:** đặt `android/key.properties` và `android/app/upload-keystore.jks` (cả hai bị gitignore). Thiếu thì build vẫn chạy nhưng ký bằng khóa debug. Tạo khóa: xem `keytool -genkeypair` trong tài liệu Flutter; đổi khóa thì phải gỡ bản cũ trên điện thoại trước khi cài.

## Kiểm thử

```bash
cd backend && .venv/bin/pytest -q                       # 226 test
cd mobile/ble_attendance_mobile && flutter analyze && flutter test   # 318 test
```

Thử BLE khi chỉ có một điện thoại: `backend/scripts/ble_teacher_sim.py` dùng Bluetooth laptop giả máy giảng viên (cần `pip install bleak`).

## Tài khoản demo (mật khẩu `Pass@123`)

Admin `A001` · Giảng viên `T001` · Sinh viên `25CE099`, `25CE100`, `D26CE045`. Tài khoản do admin tạo có mật khẩu tạm bằng mã đăng nhập và bắt buộc đổi ở lần đăng nhập đầu.

## Giới hạn đã biết

- Chỉ hỗ trợ Android cho điểm danh BLE. Android 11 trở xuống cần bật Vị trí để quét BLE.
- RSSI chỉ ước lượng độ gần. Vân tay/khóa màn hình là xác nhận phía client.
- Bắt gói rồi phát lại chỉ dùng được trong 30–60 giây; giảng viên dùng client giả vẫn gửi được detection sai (có nhật ký chỉnh tay).
- Chưa thử đầy đủ trên hai điện thoại thật: mới thử điện thoại phát + laptop quét.
- Trước khi triển khai thật: đổi `JWT_SECRET`, `BEACON_SERVER_KEY`, dùng HTTPS, thêm rate limit.
