import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

void _phoneWithLargeText(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 1.6;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

void main() {
  testWidgets('a failed poll keeps the session card and the confirm button', (
    tester,
  ) async {
    final fakes = Fakes();
    var calls = 0;
    fakes.sessions.onActive = () async {
      calls++;
      if (calls >= 2) throw ApiException('network', 'Mất kết nối');
      return sampleSession(finalizationOpen: true);
    };
    await openApp(tester, fakes: fakes);
    expect(
      find.widgetWithText(FilledButton, 'Xác nhận điểm danh'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Xác nhận điểm danh'),
      findsOneWidget,
    );
    expect(find.textContaining('Không cập nhật được'), findsOneWidget);
  });

  testWidgets('an empty classes list can be refreshed by pulling down', (
    tester,
  ) async {
    final fakes = Fakes();
    await openApp(tester, fakes: fakes, tab: 'Lớp của tôi');
    final before = fakes.stats.statsCalls;
    fakes.stats.onStats = () async => [sampleStats()];

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(fakes.stats.statsCalls, greaterThan(before));
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets(
    'an empty notifications list reloads when the unread count goes up',
    (tester) async {
      final fakes = Fakes();
      await openApp(tester, fakes: fakes, tab: 'Thông báo');
      expect(find.text('Chưa có thông báo'), findsOneWidget);

      fakes.notifications.onList = () async => [
        sampleNotification(title: 'Vừa đến'),
      ];
      fakes.notifications.onUnreadCount = () async => 1;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Vừa đến'), findsOneWidget);
    },
  );

  testWidgets(
    'the class detail summary does not overflow on a small phone with large text',
    (tester) async {
      _phoneWithLargeText(tester);
      final fakes = Fakes();
      fakes.stats.onStats = () async => [sampleStats(attendance: 100.0)];
      fakes.stats.onHistory = (_) async => [sampleHistory(lateMinutes: 12)];
      await openApp(tester, fakes: fakes, tab: 'Lớp của tôi');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Lập trình di động'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the home card does not overflow on a small phone with large text',
    (tester) async {
      _phoneWithLargeText(tester);
      final fakes = Fakes();
      fakes.sessions.onActive = () async =>
          sampleSession(finalizationOpen: true);
      await openApp(tester, fakes: fakes);
      final button = find.widgetWithText(FilledButton, 'Xác nhận điểm danh');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(button, findsNothing); // đã chuyển sang trạng thái xác nhận
      expect(
        find.text('Đã xác nhận điểm danh', skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
