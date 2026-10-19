import 'package:ble_attendance_mobile/ble/ble_gateway.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/providers/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fakes.dart';
import 'memory_token_store.dart';
import 'pump_app.dart';

/// Bộ repository giả dùng cho các test màn hình nghiệp vụ.
class Fakes {
  final classes = FakeClassRepository();
  final sessions = FakeSessionRepository();
  final stats = FakeStatsRepository();
  final leave = FakeLeaveRepository();
  final notifications = FakeNotificationRepository();
  final authenticator = FakeDeviceAuthenticator();
  final attendance = FakeAttendanceRepository();
  final reports = FakeReportRepository();
  final sharer = FakeFileSharer();
  final admin = FakeAdminRepository();
  final chooser = FakeFileChooser();
  final detections = FakeDetectionRepository();
  final ble = FakeBleGateway();
}

/// Mở app với người dùng đã đăng nhập vai trò [role] và các repository giả, rồi (tuỳ chọn) chuyển tab.
Future<Fakes> openApp(
  WidgetTester tester, {
  Fakes? fakes,
  AppRole role = AppRole.student,
  String? tab,
}) async {
  final f = fakes ?? Fakes();
  final auth = FakeAuthRepository()..onMe = () async => testUser(role: role);
  await pumpApp(
    tester,
    repo: auth,
    store: MemoryTokenStore(token: 't'),
    extra: [
      classRepositoryProvider.overrideWithValue(f.classes),
      sessionRepositoryProvider.overrideWithValue(f.sessions),
      statsRepositoryProvider.overrideWithValue(f.stats),
      leaveRepositoryProvider.overrideWithValue(f.leave),
      notificationRepositoryProvider.overrideWithValue(f.notifications),
      deviceAuthenticatorProvider.overrideWithValue(f.authenticator),
      attendanceRepositoryProvider.overrideWithValue(f.attendance),
      reportRepositoryProvider.overrideWithValue(f.reports),
      fileSharerProvider.overrideWithValue(f.sharer),
      adminRepositoryProvider.overrideWithValue(f.admin),
      fileChooserProvider.overrideWithValue(f.chooser),
      detectionRepositoryProvider.overrideWithValue(f.detections),
      bleGatewayProvider.overrideWithValue(f.ble),
    ],
  );
  if (tab != null) {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }
  return f;
}
