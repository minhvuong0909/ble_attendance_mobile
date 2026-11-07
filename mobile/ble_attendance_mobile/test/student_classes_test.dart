import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Future<Fakes> _open(WidgetTester tester, Fakes fakes) =>
    openApp(tester, fakes: fakes, tab: 'Lớp của tôi');

void main() {
  testWidgets('lists classes with attendance percent and a warning chip', (
    tester,
  ) async {
    final fakes = Fakes();
    fakes.stats.onStats = () async => [
      sampleStats(attendance: 80.0),
      sampleStats(
        classId: 'c2',
        classCode: 'SE1902',
        attendance: 50.0,
        warning: true,
      ),
    ];
    await _open(tester, fakes);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('PRM393 · SE1901 · FA26'), findsOneWidget);
    expect(find.text('Vượt mức vắng cho phép'), findsOneWidget);
  });

  testWidgets('empty state says classes are assigned by the admin', (
    tester,
  ) async {
    await _open(tester, Fakes());
    expect(find.textContaining('chưa được xếp lớp nào'), findsOneWidget);
    expect(find.textContaining('Liên hệ'), findsOneWidget);
  });

  testWidgets('students cannot join a class by themselves', (tester) async {
    final fakes = Fakes();
    fakes.stats.onStats = () async => [sampleStats()];
    await _open(tester, fakes);
    expect(find.text('Tham gia lớp'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('a loading error offers a retry', (tester) async {
    final fakes = Fakes();
    var calls = 0;
    fakes.stats.onStats = () async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return [sampleStats()];
    };
    await _open(tester, fakes);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('80%'), findsOneWidget);
  });
}
