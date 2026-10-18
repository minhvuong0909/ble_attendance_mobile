import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Future<Fakes> _openDetail(WidgetTester tester, Fakes fakes) async {
  await openApp(tester, fakes: fakes, tab: 'Lớp của tôi');
  await tester.tap(find.text('Lập trình di động'));
  await tester.pumpAndSettle();
  return fakes;
}

Fakes _fakes({bool warning = false}) {
  final fakes = Fakes();
  fakes.stats.onStats = () async => [sampleStats(warning: warning)];
  return fakes;
}

void main() {
  testWidgets('shows the summary and the history, newest first', (
    tester,
  ) async {
    final fakes = _fakes();
    fakes.stats.onHistory = (classId) async {
      expect(classId, 'c1');
      return [
        sampleHistory(
          sessionId: 's2',
          startsAt: DateTime(2026, 10, 19, 10, 0),
          status: AttendanceStatus.absent,
          ratio: 0.0,
        ),
        sampleHistory(
          sessionId: 's1',
          startsAt: DateTime(2026, 10, 18, 10, 0),
          status: AttendanceStatus.present,
          ratio: 0.9,
          lateMinutes: 3,
        ),
      ];
    };
    await _openDetail(tester, fakes);

    expect(find.text('PRM393 · SE1901'), findsWidgets);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Có mặt: 3'), findsOneWidget);
    expect(find.text('Vắng: 1'), findsOneWidget);
    expect(find.text('Có phép: 1'), findsOneWidget);
    expect(find.text('19/10/2026 10:00'), findsOneWidget);
    expect(find.text('Hiện diện 90% · Trễ 3 phút'), findsOneWidget);
    expect(find.text('Hiện diện 0%'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('19/10/2026 10:00')).dy,
      lessThan(tester.getTopLeft(find.text('18/10/2026 10:00')).dy),
    );
  });

  testWidgets('"Trễ" appears only when late minutes are above zero', (
    tester,
  ) async {
    final fakes = _fakes();
    fakes.stats.onHistory = (_) async => [sampleHistory(lateMinutes: 0)];
    await _openDetail(tester, fakes);
    expect(find.text('Hiện diện 90%'), findsOneWidget);
    expect(find.textContaining('Trễ'), findsNothing);
  });

  testWidgets('shows a warning banner when the absence limit is exceeded', (
    tester,
  ) async {
    final fakes = _fakes(warning: true);
    fakes.stats.onHistory = (_) async => [sampleHistory()];
    await _openDetail(tester, fakes);
    expect(find.textContaining('Vượt mức vắng cho phép'), findsWidgets);
    expect(find.textContaining('20%'), findsWidgets);
  });

  testWidgets('empty history', (tester) async {
    await _openDetail(tester, _fakes());
    expect(find.text('Chưa có buổi học nào kết thúc'), findsOneWidget);
  });

  testWidgets('a history loading error offers a retry', (tester) async {
    final fakes = _fakes();
    var calls = 0;
    fakes.stats.onHistory = (_) async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return [sampleHistory()];
    };
    await _openDetail(tester, fakes);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('18/10/2026 10:00'), findsOneWidget);
  });

  testWidgets('the back button returns to the class list', (tester) async {
    await _openDetail(tester, _fakes());
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Lập trình di động'), findsOneWidget);
  });
}
