import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/leave_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Fakes _fakes() {
  final fakes = Fakes();
  fakes.classes.onMyClasses = () async => [
    sampleClass(),
    sampleClass(id: 'c2', classCode: 'SE1902'),
  ];
  final byClass = {
    'c1': [
      sampleLeave(
        id: 1,
        reason: 'Việc gia đình',
        createdAt: DateTime(2026, 10, 16, 9),
      ),
      sampleLeave(
        id: 3,
        status: LeaveStatus.approved,
        reason: 'Đã duyệt từ trước',
        note: 'OK',
        createdAt: DateTime(2026, 10, 10, 9),
      ),
    ],
    'c2': [
      sampleLeave(
        id: 2,
        classId: 'c2',
        reason: 'Khám bệnh',
        studentName: 'Tran Thi B',
        createdAt: DateTime(2026, 10, 17, 9),
      ),
    ],
  };
  fakes.leave.onClassRequests = (classId, status) async => byClass[classId]!;
  return fakes;
}

Future<Fakes> _open(WidgetTester tester, [Fakes? fakes]) => openApp(
  tester,
  fakes: fakes ?? _fakes(),
  role: AppRole.teacher,
  tab: 'Xin phép',
);

Future<void> _tapReview(
  WidgetTester tester,
  String label, {
  int index = 0,
}) async {
  await tester.tap(
    find
        .widgetWithText(label == 'Duyệt' ? FilledButton : OutlinedButton, label)
        .at(index),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'merges requests of all classes, newest first, pending only by default',
    (tester) async {
      await _open(tester);
      expect(find.text('Khám bệnh'), findsOneWidget);
      expect(find.text('Việc gia đình'), findsOneWidget);
      expect(find.text('Đã duyệt từ trước'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Khám bệnh')).dy,
        lessThan(tester.getTopLeft(find.text('Việc gia đình')).dy),
      );
      expect(find.text('Tran Thi B · 25CE099'), findsOneWidget);
    },
  );

  testWidgets('the "Tất cả" filter also shows processed requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester);
    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Đã duyệt từ trước'), findsOneWidget);
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.textContaining('Phản hồi: OK'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Duyệt'),
      findsNWidgets(2),
      reason: 'only pending ones have buttons',
    );
  });

  testWidgets('approving with a note sends the trimmed note and refreshes', (
    tester,
  ) async {
    final fakes = _fakes();
    await _open(tester, fakes);
    final before = fakes.leave.classRequestCalls;

    await _tapReview(tester, 'Duyệt');
    expect(find.text('Duyệt đơn xin phép'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('review-note')),
      '  Đã nhận giấy  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle();

    expect(fakes.leave.reviewed, [
      (leaveId: 2, decision: 'approved', note: 'Đã nhận giấy'),
    ]);
    expect(find.text('Đã duyệt đơn'), findsOneWidget);
    expect(fakes.leave.classRequestCalls, greaterThan(before));
  });

  testWidgets('rejecting without a note sends null', (tester) async {
    final fakes = _fakes();
    await _open(tester, fakes);
    await _tapReview(tester, 'Từ chối');
    expect(find.text('Từ chối đơn xin phép'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle();
    expect(fakes.leave.reviewed, [
      (leaveId: 2, decision: 'rejected', note: null),
    ]);
    expect(find.text('Đã từ chối đơn'), findsOneWidget);
  });

  testWidgets('cancelling the dialog calls nothing', (tester) async {
    final fakes = _fakes();
    await _open(tester, fakes);
    await _tapReview(tester, 'Duyệt');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(fakes.leave.reviewed, isEmpty);
  });

  testWidgets('confirming twice quickly sends one review', (tester) async {
    final fakes = _fakes();
    final gate = Completer<LeaveRequest>();
    fakes.leave.onReview = (_, _, _) => gate.future;
    await _open(tester, fakes);
    await _tapReview(tester, 'Duyệt');
    final confirm = find.widgetWithText(FilledButton, 'Xác nhận');
    await tester.tap(confirm);
    await tester.pump();
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();
    gate.complete(sampleLeave());
    await tester.pumpAndSettle();
    expect(fakes.leave.reviewed, hasLength(1));
  });

  testWidgets('an already-reviewed request shows the message and refreshes', (
    tester,
  ) async {
    final fakes = _fakes();
    fakes.leave.onReview = (_, _, _) async =>
        throw ApiException('already_reviewed', 'Đơn này đã được xử lý');
    await _open(tester, fakes);
    final before = fakes.leave.classRequestCalls;
    await _tapReview(tester, 'Duyệt');
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Đơn này đã được xử lý'), findsOneWidget);
    expect(fakes.leave.classRequestCalls, greaterThan(before));
  });

  testWidgets('empty state', (tester) async {
    final fakes = Fakes();
    fakes.classes.onMyClasses = () async => [sampleClass()];
    await _open(tester, fakes);
    expect(find.text('Không có đơn nào chờ duyệt'), findsOneWidget);
  });

  testWidgets(
    'a failing class shows an error with a retry instead of hiding it',
    (tester) async {
      final fakes = _fakes();
      var calls = 0;
      final real = fakes.leave.onClassRequests;
      fakes.leave.onClassRequests = (classId, status) async {
        calls++;
        if (calls == 2) throw ApiException('network', 'Mất kết nối');
        return real(classId, status);
      };
      await _open(tester, fakes);
      expect(find.text('Mất kết nối'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Khám bệnh'), findsOneWidget);
    },
  );
}
