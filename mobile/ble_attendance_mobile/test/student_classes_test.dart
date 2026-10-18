import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Future<Fakes> _open(WidgetTester tester, Fakes fakes) =>
    openApp(tester, fakes: fakes, tab: 'Lớp của tôi');

Future<void> _openJoinDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'Tham gia lớp'));
  await tester.pumpAndSettle();
}

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

  testWidgets('empty state explains how to join a class', (tester) async {
    await _open(tester, Fakes());
    expect(find.textContaining('chưa tham gia lớp nào'), findsOneWidget);
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

  testWidgets(
    'joining with a lower-case code sends it normalized and refreshes the list',
    (tester) async {
      final fakes = Fakes();
      await _open(tester, fakes);
      final before = fakes.stats.statsCalls;
      fakes.stats.onStats = () async => [sampleStats()];

      await _openJoinDialog(tester);
      await tester.enterText(find.byKey(const Key('join-code')), ' abc123 ');
      await tester.tap(find.widgetWithText(FilledButton, 'Tham gia'));
      await tester.pumpAndSettle();

      expect(fakes.classes.joined, ['ABC123']);
      expect(find.byKey(const Key('join-code')), findsNothing);
      expect(find.text('Đã tham gia lớp PRM393 · SE1901'), findsOneWidget);
      expect(fakes.stats.statsCalls, greaterThan(before));
      expect(find.text('80%'), findsOneWidget);
    },
  );

  testWidgets('a rejected code keeps the dialog open with the server message', (
    tester,
  ) async {
    final fakes = Fakes();
    fakes.classes.onJoin = (_) async =>
        throw ApiException('invalid_join_code', 'Mã lớp không hợp lệ');
    await _open(tester, fakes);
    await _openJoinDialog(tester);
    await tester.enterText(find.byKey(const Key('join-code')), 'zzzz');
    await tester.tap(find.widgetWithText(FilledButton, 'Tham gia'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-code')), findsOneWidget);
    expect(find.text('Mã lớp không hợp lệ'), findsOneWidget);
  });

  testWidgets('an empty code is blocked before any request', (tester) async {
    final fakes = Fakes();
    await _open(tester, fakes);
    await _openJoinDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Tham gia'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập mã lớp'), findsOneWidget);
    expect(fakes.classes.joined, isEmpty);
  });

  testWidgets('cancel closes the dialog without a request', (tester) async {
    final fakes = Fakes();
    await _open(tester, fakes);
    await _openJoinDialog(tester);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-code')), findsNothing);
    expect(fakes.classes.joined, isEmpty);
  });
}
