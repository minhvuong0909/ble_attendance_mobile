import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/core/formatters.dart';
import 'package:ble_attendance_mobile/models/leave_request.dart';
import 'package:ble_attendance_mobile/screens/student/leave_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Future<Fakes> _open(WidgetTester tester, [Fakes? fakes]) =>
    openApp(tester, fakes: fakes, tab: 'Xin phép');

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'Xin phép'));
  await tester.pumpAndSettle();
}

Future<void> _pickClass(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('leave-class')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('PRM393 · SE1901').last);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Gửi đơn'));
  await tester.tap(find.widgetWithText(FilledButton, 'Gửi đơn'));
  await tester.pumpAndSettle();
}

Fakes _withClass() {
  final fakes = Fakes();
  fakes.classes.onMyClasses = () async => [sampleClass()];
  return fakes;
}

void main() {
  test('leaveDateRange allows 7 days back and 90 days ahead', () {
    final range = leaveDateRange(DateTime(2026, 10, 18, 15, 30));
    expect(range.first, DateTime(2026, 10, 11));
    expect(range.last, DateTime(2027, 1, 16));
  });

  testWidgets('lists requests with status chips and the review note', (
    tester,
  ) async {
    final fakes = Fakes();
    fakes.leave.onMine = () async => [
      sampleLeave(
        id: 2,
        status: LeaveStatus.approved,
        reason: 'Khám bệnh',
        note: 'Đã nhận giấy',
      ),
      sampleLeave(id: 1, status: LeaveStatus.pending, reason: 'Việc gia đình'),
    ];
    await _open(tester, fakes);
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.textContaining('Khám bệnh'), findsOneWidget);
    expect(find.textContaining('Đã nhận giấy'), findsOneWidget);
    expect(find.textContaining('18/10/2026'), findsWidgets);
  });

  testWidgets('empty state', (tester) async {
    await _open(tester);
    expect(find.text('Bạn chưa gửi đơn xin phép nào'), findsOneWidget);
  });

  testWidgets('a loading error offers a retry', (tester) async {
    final fakes = Fakes();
    var calls = 0;
    fakes.leave.onMine = () async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return [sampleLeave()];
    };
    await _open(tester, fakes);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chờ duyệt'), findsOneWidget);
  });

  testWidgets('the form asks to join a class first when there is none', (
    tester,
  ) async {
    await _open(tester);
    await _openForm(tester);
    expect(find.text('Hãy tham gia lớp trước khi xin phép'), findsOneWidget);
  });

  testWidgets('validation blocks a missing class and a short reason', (
    tester,
  ) async {
    final fakes = _withClass();
    await _open(tester, fakes);
    await _openForm(tester);
    await tester.enterText(find.byKey(const Key('leave-reason')), 'ab');
    await _submit(tester);
    expect(find.text('Vui lòng chọn lớp'), findsOneWidget);
    expect(find.text('Lý do cần ít nhất 3 ký tự'), findsOneWidget);
    expect(fakes.leave.created, isEmpty);
  });

  testWidgets(
    'a valid request is sent with a trimmed reason and today as the date, then the list refreshes',
    (tester) async {
      final fakes = _withClass();
      await _open(tester, fakes);
      final before = fakes.leave.mineCalls;
      await _openForm(tester);
      await _pickClass(tester);
      await tester.enterText(
        find.byKey(const Key('leave-reason')),
        '  Bị ốm phải đi khám  ',
      );
      await _submit(tester);

      final request = fakes.leave.created.single;
      expect(request.classId, 'c1');
      expect(request.reason, 'Bị ốm phải đi khám');
      expect(toApiDate(request.date), toApiDate(DateTime.now()));
      expect(find.text('Đã gửi đơn xin phép'), findsOneWidget);
      expect(find.byKey(const Key('leave-reason')), findsNothing);
      expect(fakes.leave.mineCalls, greaterThan(before));
    },
  );

  testWidgets('a server rejection is shown and the form stays open', (
    tester,
  ) async {
    final fakes = _withClass();
    fakes.leave.onCreate = (_, _, _) async => throw ApiException(
      'leave_exists',
      'Bạn đã có đơn xin phép cho ngày này',
    );
    await _open(tester, fakes);
    await _openForm(tester);
    await _pickClass(tester);
    await tester.enterText(
      find.byKey(const Key('leave-reason')),
      'Bị ốm phải đi khám',
    );
    await _submit(tester);
    expect(find.text('Bạn đã có đơn xin phép cho ngày này'), findsOneWidget);
    expect(find.byKey(const Key('leave-reason')), findsOneWidget);
  });

  testWidgets('submitting twice quickly sends one request', (tester) async {
    final fakes = _withClass();
    await _open(tester, fakes);
    await _openForm(tester);
    await _pickClass(tester);
    await tester.enterText(
      find.byKey(const Key('leave-reason')),
      'Bị ốm phải đi khám',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Gửi đơn'));
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đơn'));
    await tester.tap(
      find.widgetWithText(FilledButton, 'Gửi đơn'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(fakes.leave.created, hasLength(1));
  });
}
