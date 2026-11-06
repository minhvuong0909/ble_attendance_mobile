import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

// Mã xin quyền Bluetooth/Nearby devices dùng lại cho luồng BLE (Plan 5).

/// Xin các quyền rồi đọc lại trạng thái thật: kết quả của `request()` có thể trả về trước khi
/// người dùng bấm Cho phép (hộp thoại hệ thống đóng muộn), khiến app báo thiếu quyền oan.
Future<bool> _requestAll(List<Permission> permissions) async {
  final statuses = await permissions.request();
  for (final permission in permissions) {
    var status = statuses[permission] ?? await permission.status;
    if (!status.isGranted && !status.isLimited) {
      status = await permission.status;
    }
    if (!status.isGranted && !status.isLimited) return false;
  }
  return true;
}

Future<bool> ensureBlePermissions() async {
  final ok = await _requestAll([
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
  ]);
  if (!ok) return false;

  await Permission.locationWhenInUse.request();
  return true;
}

Future<bool> ensureBleAdvertisePermissions() async {
  return _requestAll([
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
  ]);
}

Future<bool> ensureBleScanPermissions() async {
  final ok = await _requestAll([
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ]);
  if (!ok) return false;

  await Permission.locationWhenInUse.request();
  return true;
}

Future<void> ensureBluetoothEnabled() async {
  if (!_isAndroid) return;
  try {
    const intent = AndroidIntent(
      action: 'android.bluetooth.adapter.action.REQUEST_ENABLE',
    );
    await intent.launch();
  } catch (_) {
    // Giao diện sẽ hiển thị trạng thái Bluetooth nếu thao tác thất bại.
  }
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
