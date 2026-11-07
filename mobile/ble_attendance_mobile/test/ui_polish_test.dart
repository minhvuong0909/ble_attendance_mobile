import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/class_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fakes.dart';
import 'helpers/harness.dart';
import 'helpers/memory_token_store.dart';
import 'helpers/pump_app.dart';

void _narrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Fakes _teacherFakes() {
  final fakes = Fakes();
  fakes.classes.onMyClasses = () async => [sampleClass(joinCode: 'ABC123')];
  fakes.reports.onReport = (_) async => sampleReport(
    average: 66.7,
    sessions: [
      ReportSession(id: 's1', startsAt: DateTime(2026, 10, 1, 10)),
      ReportSession(id: 's2', startsAt: DateTime(2026, 10, 2, 10)),
      ReportSession(id: 's3', startsAt: DateTime(2026, 10, 3, 10)),
    ],
    students: [
      sampleReportStudent(
        id: 'u1',
        studentId: '25CE099',
        name: 'Nguyen Van A',
        cells: [
          AttendanceStatus.present,
          AttendanceStatus.present,
          AttendanceStatus.absent,
        ],
        present: 2,
        absent: 1,
      ),
    ],
  );
  return fakes;
}

Future<void> _openClass(WidgetTester tester, Fakes fakes) async {
  await openApp(tester, fakes: fakes, role: AppRole.teacher);
  await tester.tap(find.text('Lập trình di động'));
  await tester.pumpAndSettle();
}

void main() {
  group('teacher classes list', () {
    testWidgets('each card shows a chevron so it reads as tappable', (
      tester,
    ) async {
      await openApp(tester, fakes: _teacherFakes(), role: AppRole.teacher);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('rssi dialog', () {
    testWidgets('the three presets share one row', (tester) async {
      _narrowPhone(tester);
      await _openClass(tester, _teacherFakes());
      await tester.tap(find.byTooltip('Ngưỡng RSSI'));
      await tester.pumpAndSettle();
      final ys = [
        for (final label in ['Nhỏ -70', 'Vừa -75', 'Lớn -85'])
          tester.getTopLeft(find.text(label)).dy,
      ];
      expect(ys[1], ys[0]);
      expect(ys[2], ys[0]);
    });
  });

  group('class report table', () {
    Future<void> openReport(WidgetTester tester) async {
      _narrowPhone(tester);
      await _openClass(tester, _teacherFakes());
      await tester.tap(find.text('Báo cáo'));
      await tester.pumpAndSettle();
    }

    testWidgets('the student column stays put while the days scroll', (
      tester,
    ) async {
      await openReport(tester);
      final nameX = tester.getTopLeft(find.text('Nguyen Van A')).dx;
      final dayX = tester.getTopLeft(find.text('01/10')).dx;
      await tester.drag(find.text('01/10'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Nguyen Van A')).dx, nameX);
      expect(tester.getTopLeft(find.text('01/10')).dx, lessThan(dayX));
    });

    testWidgets('the last column keeps a margin from the right edge', (
      tester,
    ) async {
      await openReport(tester);
      await tester.drag(find.text('01/10'), const Offset(-3000, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getTopRight(find.text('%')).dx,
        lessThanOrEqualTo(360 - 12),
      );
    });
  });

  group('device change request', () {
    Future<void> openDialog(
      WidgetTester tester,
      FakeAuthRepository repo,
    ) async {
      await pumpApp(
        tester,
        repo: repo,
        store: MemoryTokenStore(deviceId: 'phone-1'),
      );
      await tester.enterText(find.byKey(const Key('login-id')), '25CE099');
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'Pass@123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi đơn đổi thiết bị'));
      await tester.pumpAndSettle();
    }

    FakeAuthRepository mismatchRepo() => FakeAuthRepository()
      ..onLogin = (id, password) async =>
          throw ApiException('device_mismatch', 'Máy khác', statusCode: 403);

    testWidgets('the reason field is focused as soon as the dialog opens', (
      tester,
    ) async {
      await openDialog(tester, mismatchRepo());
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('device-reason')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.focusNode.hasFocus, isTrue);
    });

    testWidgets('the confirmation is a banner with a check icon', (
      tester,
    ) async {
      await openDialog(tester, mismatchRepo());
      await tester.enterText(find.byKey(const Key('device-reason')), 'Đổi máy');
      await tester.tap(find.widgetWithText(FilledButton, 'Gửi đơn'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.textContaining('Đã gửi đơn đổi thiết bị'), findsOneWidget);
    });
  });
}
