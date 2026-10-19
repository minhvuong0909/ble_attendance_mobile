import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/class_report.dart';
import 'package:ble_attendance_mobile/models/session_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

SessionInfo _ended() => SessionInfo(
  id: 's1',
  classId: 'c1',
  classCode: 'SE1901',
  courseCode: 'PRM393',
  courseName: 'Lập trình di động',
  teacherUserId: 't1',
  beaconCode: 'abcd1234',
  startsAt: DateTime(2026, 10, 18, 10, 0),
  endsAt: DateTime(2026, 10, 18, 11, 30),
  isActive: false,
  finalizationOpen: false,
  beaconSecret: null,
);

void _phoneWithLargeText(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 1.6;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

Fakes _fakes() {
  final fakes = Fakes();
  fakes.classes.onMyClasses = () async => [sampleClass(joinCode: 'ABC123')];
  fakes.sessions.onClassSessions = (_) async => [_ended()];
  fakes.attendance.onAttendance = (_) async => sampleAttendance(
    records: [
      sampleRecord(id: 'u1', studentId: '25CE099', name: 'Nguyen Van A'),
      sampleRecord(
        id: 'u2',
        studentId: '25CE100',
        name: 'Tran Thi B',
        status: AttendanceStatus.present,
      ),
    ],
  );
  return fakes;
}

Future<void> _openSessionsTab(WidgetTester tester, Fakes fakes) async {
  await openApp(tester, fakes: fakes, role: AppRole.teacher);
  await tester.tap(find.text('Lập trình di động'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Buổi học'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'an ended session can be opened to review, correct and export its final results',
    (tester) async {
      final fakes = _fakes();
      await _openSessionsTab(tester, fakes);
      await tester.tap(find.text('18/10/2026 10:00'));
      await tester.pumpAndSettle();

      expect(find.text('Có mặt 1 / 2 sinh viên'), findsOneWidget);
      expect(find.text('25CE099 · Nguyen Van A'), findsOneWidget);

      await tester.tap(find.text('25CE099 · Nguyen Van A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Có mặt').last);
      await tester.enterText(
        find.byKey(const Key('override-reason')),
        'Điện thoại hết pin',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(fakes.attendance.overrides.single.studentUserId, 'u1');
      expect(
        fakes.attendance.overrides.single.status,
        AttendanceStatus.present,
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Xuất Excel buổi này'),
      );
      await tester.pumpAndSettle();
      expect(fakes.reports.exportedSessions, ['s1']);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Bắt đầu buổi học'), findsOneWidget);
    },
  );

  testWidgets('the end dialog warns when finalization was never opened', (
    tester,
  ) async {
    final fakes = Fakes();
    fakes.sessions.onActive = () async =>
        sampleSession(finalizationOpen: false);
    await openApp(
      tester,
      fakes: fakes,
      role: AppRole.teacher,
      tab: 'Buổi trực tiếp',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Kết thúc buổi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa mở chốt điểm danh'), findsOneWidget);
    expect(find.textContaining('vắng'), findsWidgets);
  });

  testWidgets(
    'the end dialog has no extra warning once finalization was opened',
    (tester) async {
      final fakes = Fakes();
      fakes.sessions.onActive = () async =>
          sampleSession(finalizationOpen: true);
      await openApp(
        tester,
        fakes: fakes,
        role: AppRole.teacher,
        tab: 'Buổi trực tiếp',
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Kết thúc buổi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa mở chốt điểm danh'), findsNothing);
    },
  );

  testWidgets(
    'the sessions tab and the report tab do not break on a small phone with large text',
    (tester) async {
      _phoneWithLargeText(tester);
      final fakes = _fakes();
      fakes.sessions.onClassSessions = (_) async => [sampleSession(), _ended()];
      fakes.reports.onReport = (_) async => sampleReport(
        average: 80,
        sessions: [
          ReportSession(id: 's1', startsAt: DateTime(2026, 10, 1, 10)),
        ],
        students: [
          sampleReportStudent(cells: [AttendanceStatus.present], present: 1),
        ],
      );
      await _openSessionsTab(tester, fakes);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Báo cáo'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a report with students but no sessions can be refreshed by pulling down',
    (tester) async {
      final fakes = _fakes();
      fakes.reports.onReport = (_) async =>
          sampleReport(students: [sampleReportStudent()]);
      await openApp(tester, fakes: fakes, role: AppRole.teacher);
      await tester.tap(find.text('Lập trình di động'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Báo cáo'));
      await tester.pumpAndSettle();
      expect(find.text('Lớp chưa có buổi học nào kết thúc'), findsOneWidget);
      final before = fakes.reports.reportCalls;

      await tester.drag(
        find.text('Lớp chưa có buổi học nào kết thúc'),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(fakes.reports.reportCalls, greaterThan(before));
    },
  );
}
