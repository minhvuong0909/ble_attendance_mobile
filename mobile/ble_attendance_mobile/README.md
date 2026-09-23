# Ứng dụng Flutter điểm danh BLE

## Cấu trúc mã nguồn

```text
lib/
├── core/
│   └── app_constants.dart
├── models/
│   ├── app_role.dart
│   └── student_tally.dart
├── services/
│   └── api_client.dart
└── main.dart
```

- `core/`: cấu hình và hằng số dùng chung
- `models/`: kiểu dữ liệu không phụ thuộc giao diện
- `services/`: giao tiếp API và lưu phiên đăng nhập
- `main.dart`: điểm khởi chạy và các màn hình

## Chạy ứng dụng

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.7:8000
```

Điện thoại và máy chạy backend phải ở cùng mạng Wi-Fi.

## Kiểm tra

```powershell
dart format lib test
flutter analyze
flutter test
```

## Lưu ý

- Android cần quyền Nearby devices, Bluetooth và foreground service.
- iOS cần thử BLE trên thiết bị vật lý.
- Không force-close ứng dụng trong lúc điểm danh.
- Lưu Excel hiện dùng đường dẫn Android và chưa hỗ trợ iOS đầy đủ.
