import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/leave_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Future<void> _selectTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Fakes _teacherFakes(List<LeaveRequest> Function() leaves) {
  final fakes = Fakes();
  fakes.classes.onMyClasses = () async => [sampleClass()];
  fakes.leave.onClassRequests = (_, _) async => leaves();
  return fakes;
}

void main() {
  testWidgets(
    'a request sent after the teacher leave tab was first opened appears when returning to it',
    (tester) async {
      var leaves = <LeaveRequest>[];
      final fakes = _teacherFakes(() => leaves);
      await openApp(
        tester,
        fakes: fakes,
        role: AppRole.teacher,
        tab: 'Xin phép',
      );
      expect(find.text('Không có đơn nào chờ duyệt'), findsOneWidget);

      leaves = [sampleLeave(reason: 'Bệnh sốt nặng')];
      await _selectTab(tester, 'Lớp học');
      await _selectTab(tester, 'Xin phép');

      expect(find.text('Bệnh sốt nặng'), findsOneWidget);
    },
  );

  testWidgets('a new notification refreshes the visible leave list by itself', (
    tester,
  ) async {
    var leaves = <LeaveRequest>[];
    final fakes = _teacherFakes(() => leaves);
    await openApp(tester, fakes: fakes, role: AppRole.teacher, tab: 'Xin phép');
    expect(find.text('Không có đơn nào chờ duyệt'), findsOneWidget);

    leaves = [sampleLeave(reason: 'Việc gia đình')];
    fakes.notifications.onUnreadCount = () async => 1;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Việc gia đình'), findsOneWidget);
  });

  testWidgets(
    'the student leave list shows a new review result after a new notification',
    (tester) async {
      var status = LeaveStatus.pending;
      final fakes = Fakes();
      fakes.leave.onMine = () async => [sampleLeave(status: status)];
      await openApp(tester, fakes: fakes, tab: 'Xin phép');
      expect(find.text('Chờ duyệt'), findsOneWidget);

      status = LeaveStatus.approved;
      fakes.notifications.onUnreadCount = () async => 1;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('Đã duyệt'), findsOneWidget);
    },
  );

  testWidgets('selecting the student classes tab shows fresh statistics', (
    tester,
  ) async {
    var percent = 100.0;
    final fakes = Fakes();
    fakes.stats.onStats = () async => [sampleStats(attendance: percent)];
    await openApp(tester, fakes: fakes, tab: 'Lớp của tôi');
    expect(find.text('100%'), findsOneWidget);

    percent = 50.0;
    await _selectTab(tester, 'Trang chủ');
    await _selectTab(tester, 'Lớp của tôi');
    expect(find.text('50%'), findsOneWidget);
  });
}
