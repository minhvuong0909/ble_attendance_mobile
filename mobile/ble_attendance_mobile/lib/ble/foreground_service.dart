import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// Dịch vụ nền Android giữ cho BLE quét/phát không bị hệ thống dừng (Plan 5).

void initForegroundTask() {
  if (!_isAndroid) return;
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'ble_attendance_fg',
      channelName: 'BLE Attendance',
      channelDescription: 'Keeps BLE scanning/advertising alive',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );
}

Future<void> startForegroundService(String text) async {
  if (!_isAndroid) return;
  await FlutterForegroundTask.startService(
    notificationTitle: 'BLE Attendance',
    notificationText: text,
  );
}

Future<void> stopForegroundService() async {
  if (!_isAndroid) return;
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.stopService();
  }
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
