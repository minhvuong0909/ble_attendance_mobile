import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:ble_attendance_mobile/data/class_repository.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/fakes.dart';
import 'helpers/harness.dart';
import 'helpers/memory_token_store.dart';

Future<Fakes> _openDetail(WidgetTester tester) async {
  final fakes = Fakes();
  fakes.classes.onMyClasses = () async => [sampleClass(joinCode: 'ABC123')];
  await openApp(tester, fakes: fakes, role: AppRole.teacher);
  await tester.tap(find.text('Lập trình di động'));
  await tester.pumpAndSettle();
  return fakes;
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ngưỡng RSSI'));
  await tester.pumpAndSettle();
}

void main() {
  test('repository patches the class RSSI and parses the class', () async {
    final adapter = FakeAdapter(
      (options) async => jsonBody({
        'id': 'c1',
        'course_id': 'k1',
        'course_code': 'PRM393',
        'course_name': 'Lập trình di động',
        'class_code': 'SE1901',
        'semester': 'FA26',
        'teacher_user_id': 't1',
        'teacher_name': 'Co Lan',
        'join_code': 'ABC123',
        'max_absence_percent': 20,
        'rssi_threshold': -85,
        'student_count': 30,
      }),
    );
    final repo = ApiClassRepository(
      ApiClient(
        store: MemoryTokenStore(),
        dio: Dio()..httpClientAdapter = adapter,
        defaultBaseUrl: 'http://x',
      ),
    );
    final info = await repo.updateRssi('c1', -85);
    expect(info.rssiThreshold, -85);
    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/classes/c1/rssi');
    expect(request.data, {'rssi_threshold': -85});
  });

  testWidgets('the app bar action opens a dialog with the current threshold', (
    tester,
  ) async {
    await _openDetail(tester);
    await _openDialog(tester);
    expect(find.text('Ngưỡng RSSI của lớp'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('rssi-field')))
          .controller!
          .text,
      '-75',
    );
  });

  testWidgets('a preset fills the field and saving refreshes the classes', (
    tester,
  ) async {
    final fakes = await _openDetail(tester);
    final callsBefore = fakes.classes.myClassesCalls;
    await _openDialog(tester);
    await tester.tap(find.text('Lớn -85'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(fakes.classes.rssiUpdates, [('c1', -85)]);
    expect(find.text('Đã lưu ngưỡng RSSI'), findsOneWidget);
    expect(find.text('Ngưỡng RSSI của lớp'), findsNothing);
    expect(fakes.classes.myClassesCalls, greaterThan(callsBefore));
  });

  testWidgets('a typed value is sent as an integer', (tester) async {
    final fakes = await _openDetail(tester);
    await _openDialog(tester);
    await tester.enterText(find.byKey(const Key('rssi-field')), '-82');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(fakes.classes.rssiUpdates, [('c1', -82)]);
  });

  testWidgets('out-of-range or non-numeric values are blocked', (tester) async {
    final fakes = await _openDetail(tester);
    await _openDialog(tester);
    for (final bad in ['-20', '-101', 'abc', '']) {
      await tester.enterText(find.byKey(const Key('rssi-field')), bad);
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Ngưỡng RSSI từ -100 đến -30'), findsOneWidget);
    }
    expect(fakes.classes.rssiUpdates, isEmpty);
  });

  testWidgets('a server error stays in the dialog', (tester) async {
    final fakes = await _openDetail(tester);
    fakes.classes.onUpdateRssi = (_, _) async => throw ApiException(
      'forbidden',
      'Bạn không được phân công lớp này',
      statusCode: 403,
    );
    await _openDialog(tester);
    await tester.enterText(find.byKey(const Key('rssi-field')), '-90');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn không được phân công lớp này'), findsOneWidget);
    expect(find.text('Ngưỡng RSSI của lớp'), findsOneWidget);
  });
}
