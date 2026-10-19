import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/core/formatters.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/session_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

class _Live {
  _Live() {
    fakes.sessions.onActive = () async => active;
    fakes.sessions.onOpen = (_) async {
      active = sampleSession(finalizationOpen: true);
      return active!;
    };
    fakes.sessions.onEnd = (_) async {
      final ended = active!;
      active = null;
      return ended;
    };
    fakes.attendance.onAttendance = (_) async => attendance;
  }

  final fakes = Fakes();
  SessionInfo? active = sampleSession();
  var attendance = sampleAttendance(
    records: [
      sampleRecord(
        id: 'u1',
        studentId: '25CE099',
        name: 'Nguyen Van A',
        status: AttendanceStatus.present,
        ratio: 0.9,
        detections: 12,
        finalized: true,
        firstSeenAt: DateTime(2026, 10, 18, 10, 3, 20),
      ),
      sampleRecord(
        id: 'u2',
        studentId: '25CE100',
        name: 'Tran Thi B',
        status: AttendanceStatus.absent,
        overridden: true,
        reason: 'Vắng không phép',
      ),
    ],
  );
}

Future<_Live> _open(WidgetTester tester, [_Live? live]) async {
  final l = live ?? _Live();
  await openApp(
    tester,
    fakes: l.fakes,
    role: AppRole.teacher,
    tab: 'Buổi trực tiếp',
  );
  return l;
}

Future<void> _tapRecord(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  test('lateMinutes floors to whole minutes and never goes negative', () {
    final start = DateTime(2026, 10, 18, 10);
    expect(lateMinutes(start, DateTime(2026, 10, 18, 10, 3, 59)), 3);
    expect(lateMinutes(start, DateTime(2026, 10, 18, 9, 59)), 0);
    expect(lateMinutes(start, null), isNull);
  });

  testWidgets('shows a hint when no session is running', (tester) async {
    final live = _Live()..active = null;
    await _open(tester, live);
    expect(find.text('Bạn chưa bắt đầu buổi học nào'), findsOneWidget);
  });

  testWidgets('shows the session, the summary and every student', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Lập trình di động'), findsOneWidget);
    expect(find.text('Có mặt 1 / 2 sinh viên'), findsOneWidget);
    expect(find.text('25CE099 · Nguyen Van A'), findsOneWidget);
    expect(find.textContaining('Hiện diện 90%'), findsOneWidget);
    expect(find.textContaining('12 lần phát hiện'), findsOneWidget);
    expect(find.textContaining('Đã chốt'), findsOneWidget);
    expect(find.textContaining('Trễ 3 phút'), findsOneWidget);
    expect(
      find.textContaining('Đã chỉnh tay: Vắng không phép'),
      findsOneWidget,
    );
  });

  testWidgets(
    'opening finalization calls the API once and switches to "Đã mở chốt"',
    (tester) async {
      final live = _Live();
      final gate = Completer<void>();
      final real = live.fakes.sessions.onOpen;
      live.fakes.sessions.onOpen = (id) async {
        await gate.future;
        return real(id);
      };
      await _open(tester, live);
      final button = find.widgetWithText(FilledButton, 'Mở chốt điểm danh');
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(live.fakes.sessions.opened, ['s1']);
      expect(find.text('Đã mở chốt'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Mở chốt điểm danh'),
        findsNothing,
      );
    },
  );

  testWidgets('ending a session asks for confirmation first', (tester) async {
    final live = _Live();
    await _open(tester, live);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Kết thúc buổi'));
    await tester.pumpAndSettle();
    expect(find.text('Kết thúc buổi học?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(live.fakes.sessions.ended, isEmpty);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Kết thúc buổi'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Kết thúc');
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(live.fakes.sessions.ended, ['s1']);
    expect(find.text('Đã kết thúc buổi học'), findsOneWidget);
    expect(find.text('Bạn chưa bắt đầu buổi học nào'), findsOneWidget);
  });

  testWidgets('a failed end shows the server message and keeps the session', (
    tester,
  ) async {
    final live = _Live();
    live.fakes.sessions.onEnd = (_) async =>
        throw ApiException('network', 'Mất kết nối');
    await _open(tester, live);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Kết thúc buổi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Kết thúc'));
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);
    expect(find.text('Lập trình di động'), findsOneWidget);
  });

  testWidgets('overriding validates, sends a trimmed reason and refreshes', (
    tester,
  ) async {
    final live = _Live();
    await _open(tester, live);
    final before = live.fakes.attendance.attendanceCalls;

    await _tapRecord(tester, '25CE100 · Tran Thi B');
    expect(find.text('Chỉnh tay điểm danh'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Lý do cần ít nhất 3 ký tự'), findsOneWidget);
    expect(live.fakes.attendance.overrides, isEmpty);

    await tester.tap(find.text('Có phép'));
    await tester.enterText(
      find.byKey(const Key('override-reason')),
      '  Có giấy xin phép  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    final call = live.fakes.attendance.overrides.single;
    expect(call.studentUserId, 'u2');
    expect(call.status, AttendanceStatus.excused);
    expect(call.reason, 'Có giấy xin phép');
    expect(find.text('Chỉnh tay điểm danh'), findsNothing);
    expect(find.text('Đã cập nhật điểm danh'), findsOneWidget);
    expect(live.fakes.attendance.attendanceCalls, greaterThan(before));
  });

  testWidgets('a rejected override keeps the dialog open with the message', (
    tester,
  ) async {
    final live = _Live();
    live.fakes.attendance.onOverride = (_, _, _, _) async => throw ApiException(
      'student_not_in_class',
      'Sinh viên không thuộc lớp này',
    );
    await _open(tester, live);
    await _tapRecord(tester, '25CE099 · Nguyen Van A');
    await tester.enterText(
      find.byKey(const Key('override-reason')),
      'Lý do hợp lệ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Sinh viên không thuộc lớp này'), findsOneWidget);
    expect(find.text('Chỉnh tay điểm danh'), findsOneWidget);
  });

  testWidgets('the list refreshes every 10 seconds', (tester) async {
    final live = _Live();
    await _open(tester, live);
    final before = live.fakes.attendance.attendanceCalls;
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(live.fakes.attendance.attendanceCalls, greaterThan(before));
  });

  testWidgets('a failed refresh keeps the list and shows a warning', (
    tester,
  ) async {
    final live = _Live();
    await _open(tester, live);
    live.fakes.attendance.onAttendance = (_) async =>
        throw ApiException('network', 'Mất kết nối');
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('25CE099 · Nguyen Van A'), findsOneWidget);
    expect(find.textContaining('Không cập nhật được'), findsOneWidget);
  });

  testWidgets('exports the session workbook', (tester) async {
    final live = _Live();
    await _open(tester, live);
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Xuất Excel buổi này'),
    );
    await tester.pumpAndSettle();
    expect(live.fakes.reports.exportedSessions, ['s1']);
    expect(live.fakes.sharer.shared, hasLength(1));
  });
}
