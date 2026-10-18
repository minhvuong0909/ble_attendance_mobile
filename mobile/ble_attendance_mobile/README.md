# Ứng dụng Flutter điểm danh BLE (Android)

Một ứng dụng dùng chung cho **admin**, **giảng viên** và **sinh viên**. Vai trò do server quyết định (`GET /auth/me`), giao diện tiếng Việt.

## Cấu trúc mã nguồn

```text
lib/
├── main.dart            ProviderScope + App
├── app/                 app.dart, router.dart (go_router + authRedirect), theme.dart
├── core/                hằng số, ApiException (lỗi tiếng Việt), validators
├── models/              AppRole, AuthUser
├── data/                ApiClient (Dio), TokenStore, AuthRepository
├── providers/           Riverpod: core_providers, auth_controller
├── ble/                 quyền Bluetooth và dịch vụ nền Android (dùng lại cho luồng BLE)
├── screens/auth/        splash, đăng nhập, đăng ký, đổi mật khẩu, cài đặt máy chủ
├── screens/shell/       khung điều hướng 3 vai trò (tab giữ chỗ)
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
- Các tab nghiệp vụ hiện là giữ chỗ; xem `docs/superpowers/plans/` để biết lộ trình.
