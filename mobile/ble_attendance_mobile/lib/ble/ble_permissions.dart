import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

// Mã xin quyền Bluetooth/Nearby devices dùng lại cho luồng BLE (Plan 5).

Future<bool> ensureBlePermissions() async {
  final bleStatuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
  ].request();

  for (final status in bleStatuses.values) {
    if (!status.isGranted && !status.isLimited) return false;
  }

  await Permission.locationWhenInUse.request();
  return true;
}

Future<bool> ensureBleAdvertisePermissions() async {
  final bleStatuses = await [
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
  ].request();

  for (final status in bleStatuses.values) {
    if (!status.isGranted && !status.isLimited) return false;
  }
  return true;
}

Future<bool> ensureBleScanPermissions() async {
  final bleStatuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ].request();

  for (final status in bleStatuses.values) {
    if (!status.isGranted && !status.isLimited) return false;
  }

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
