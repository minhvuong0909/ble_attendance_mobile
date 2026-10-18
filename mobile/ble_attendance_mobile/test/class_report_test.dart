import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/core/formatters.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/class_report.dart';
import 'package:ble_attendance_mobile/models/export_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

const _p = AttendanceStatus.present;
const _a = AttendanceStatus.absent;
const _e = AttendanceStatus.excused;

Fakes _fakes({ClassReport? report}) {
  final fakes = Fakes();
  fakes.classes.onMyClasses = () async => [sampleClass(joinCode: 'ABC123')];
  fakes.reports.onReport = (_) async =>
      report ??
      sampleReport(
        average: 66.7,
        sessions: [
          ReportSession(id: 's1', startsAt: DateTime(2026, 10, 1, 10)),
          ReportSession(id: 's2', startsAt: DateTime(2026, 10, 2, 10)),
        ],
        students: [
          sampleReportStudent(
            id: 'u1',
            studentId: '25CE099',
            name: 'Nguyen Van A',
            cells: [_p, _p],
            present: 2,
          ),
          sampleReportStudent(
            id: 'u2',
            studentId: '25CE100',
            name: 'Tran Thi B',
            cells: [_a, null],
            absent: 1,
            percent: 0,
            warning: true,
          ),
          sampleReportStudent(
            id: 'u3',
            studentId: '25CE101',
            name: 'Le Van C',
            cells: [_e, _p],
            present: 1,
            excused: 1,
            percent: 100,
          ),
        ],
      );
  return fakes;
}

Future<Fakes> _openReport(WidgetTester tester, Fakes fakes) async {
  await openApp(tester, fakes: fakes, role: AppRole.teacher);
  await tester.tap(find.text('Lập trình di động'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Báo cáo'));
  await tester.pumpAndSettle();
  return fakes;
}

void main() {
  test('formatPercent drops a useless .0', () {
    expect(formatPercent(100.0), '100%');
    expect(formatPercent(66.7), '66.7%');
    expect(formatPercent(0), '0%');
  });

  testWidgets('shows the matrix, totals, empty cells and the warning', (
    tester,
  ) async {
    await _openReport(tester, _fakes());
    expect(find.text('Trung bình lớp: 66.7%'), findsOneWidget);
    expect(find.text('3 sinh viên · 2 buổi'), findsOneWidget);
    expect(find.text('01/10'), findsOneWidget);
    expect(find.text('02/10'), findsOneWidget);
    expect(find.text('25CE099'), findsOneWidget);
    expect(find.text('Tran Thi B'), findsOneWidget);
    expect(find.text('P'), findsNWidgets(3));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(find.text('–'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.byTooltip('Vượt mức vắng cho phép'), findsOneWidget);
  });

  testWidgets('a class without ended sessions', (tester) async {
    await _openReport(
      tester,
      _fakes(report: sampleReport(students: [sampleReportStudent()])),
    );
    expect(find.text('Lớp chưa có buổi học nào kết thúc'), findsOneWidget);
  });

  testWidgets('a class without students', (tester) async {
    await _openReport(tester, _fakes(report: sampleReport()));
    expect(find.text('Chưa có sinh viên trong lớp'), findsOneWidget);
  });

  testWidgets('a loading error offers a retry', (tester) async {
    final fakes = _fakes();
    var calls = 0;
    final real = fakes.reports.onReport;
    fakes.reports.onReport = (id) async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return real(id);
    };
    await _openReport(tester, fakes);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Trung bình lớp: 66.7%'), findsOneWidget);
  });

  testWidgets('exporting shares the file once even if tapped twice', (
    tester,
  ) async {
    final fakes = _fakes();
    final gate = Completer<ExportFile>();
    fakes.reports.onExport = () => gate.future;
    await _openReport(tester, fakes);

    final button = find.widgetWithText(OutlinedButton, 'Xuất Excel');
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    gate.complete(
      const ExportFile(filename: 'attendance_PRM393.xlsx', bytes: [9, 9]),
    );
    await tester.pumpAndSettle();

    expect(fakes.reports.exportedClasses, ['c1']);
    expect(fakes.sharer.shared.single.filename, 'attendance_PRM393.xlsx');
    expect(fakes.sharer.shared.single.bytes, [9, 9]);
  });

  testWidgets('a failed export is reported and the button works again', (
    tester,
  ) async {
    final fakes = _fakes();
    var calls = 0;
    fakes.reports.onExport = () async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return const ExportFile(filename: 'ok.xlsx', bytes: [1]);
    };
    await _openReport(tester, fakes);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Xuất Excel'));
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);
    expect(fakes.sharer.shared, isEmpty);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Xuất Excel'));
    await tester.pumpAndSettle();
    expect(fakes.sharer.shared.single.filename, 'ok.xlsx');
  });
}
