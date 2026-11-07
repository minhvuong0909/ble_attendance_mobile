import 'dart:math';

/// Mã thiết bị ngẫu nhiên (128 bit, 32 ký tự hex). Gỡ cài đặt hoặc xóa dữ liệu ứng dụng
/// sẽ mất mã này và tài khoản phải xin admin đổi thiết bị, đúng chủ đích.
String newDeviceId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
