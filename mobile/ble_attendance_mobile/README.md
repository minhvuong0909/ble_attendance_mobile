# Ứng dụng Flutter điểm danh BLE (Android)

Một ứng dụng dùng chung cho **admin**, **giảng viên** và **sinh viên**. Vai trò do server quyết định (`GET /auth/me`), giao diện tiếng Việt.

## Cấu trúc mã nguồn

```text
lib/
├── main.dart            ProviderScope + App
├── app/                 app.dart, router.dart (go_router + authRedirect), theme.dart
├── core/                hằng số, ApiException (lỗi tiếng Việt), validators
├── models/              AppRole, AuthUser, ClassInfo, SessionInfo, ClassStats, LeaveRequest, ...
├── data/                ApiClient (Dio), TokenStore và các repository (auth, lớp, buổi học, thống kê, xin phép, thông báo)
├── providers/           Riverpod: auth, repositories, notifications, stats, leave, student_beacon, teacher_beacon
├── ble/                 mã hóa gói + tag HMAC, BleGateway (phát/quét), quyền Bluetooth, dịch vụ nền
├── screens/auth/        splash, đăng nhập, đăng ký, đổi mật khẩu, cài đặt máy chủ
├── screens/shell/       khung điều hướng 3 vai trò (tab giữ chỗ cho phần chưa làm)
├── screens/student/     trang chủ, lớp của tôi + chi tiết, xin phép
├── screens/teacher/     lớp được phân công (sinh viên, buổi học, báo cáo + Excel), buổi trực tiếp, duyệt xin phép
├── screens/admin/       môn học, lớp (tạo, cấu hình, gán giảng viên), giảng viên, sinh viên, import CSV/Excel có xem trước
├── screens/notifications/ thông báo (dùng chung, có badge chưa đọc)
└── widgets/             thành phần dùng chung
```

## Chạy ứng dụng

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.7:8000
```

Điện thoại và máy chạy backend phải cùng mạng Wi-Fi. Địa chỉ máy chủ cũng đổi được trong app (biểu tượng bánh răng ở màn hình đăng nhập).

## Kiểm tra

```bash
dart format lib test
flutter analyze
flutter test
```

## Lưu ý

- Chỉ hỗ trợ Android (cần quyền Nearby devices, Bluetooth và dịch vụ nền).
- Tài khoản mới do admin tạo có mật khẩu tạm bằng mã định danh; lần đầu đăng nhập app bắt buộc đổi mật khẩu.
- Đã có: màn hình sinh viên (buổi học đang diễn ra + chốt điểm danh bằng vân tay/khóa màn hình, lớp của tôi, thống kê chuyên cần, xin phép) và thông báo.
- Đã có thêm: màn hình giảng viên (lớp, bắt đầu/kết thúc buổi, mở chốt, chỉnh tay điểm danh, báo cáo + xuất Excel, duyệt đơn xin phép).
- Đã có thêm: màn hình admin (môn học, lớp, giảng viên, sinh viên, import danh sách có xem trước).
- Đã có BLE: sinh viên phát tag HMAC và thấy gần/xa lớp; giảng viên quét và gửi lô detection mỗi 30 giây (xem `docs/superpowers/STATUS.md` mục Thử BLE).
- Build web: `backend/scripts/build_web.sh`. Android ≤ 11 cần bật Vị trí để quét BLE.
