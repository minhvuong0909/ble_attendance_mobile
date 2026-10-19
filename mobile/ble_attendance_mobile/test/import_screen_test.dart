import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/data/file_chooser.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/import_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Fakes _fakes() {
  final fakes = Fakes();
  fakes.admin.onTeachers = () async => [sampleTeacher()];
  fakes.admin.onAllClasses = () async => [sampleClass(joinCode: 'ABC123')];
  fakes.classes.onStudents = (_) async => [sampleStudent()];
  return fakes;
}

Future<Fakes> _openTeachers(WidgetTester tester, [Fakes? fakes]) async {
  final f = fakes ?? _fakes();
  await openApp(tester, fakes: f, role: AppRole.admin, tab: 'Giảng viên');
  await tester.tap(find.text('Nhập từ file'));
  await tester.pumpAndSettle();
  return f;
}

Future<void> _pick(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Chọn file'));
  await tester.pumpAndSettle();
}

ImportReport _withError() => sampleImportReport(
  rows: const [
    ImportRow(
      row: 2,
      status: ImportRowStatus.created,
      message: 'Tạo tài khoản giảng viên',
    ),
    ImportRow(
      row: 3,
      status: ImportRowStatus.error,
      message: 'Mã giảng viên phải dài từ 3 đến 16 ký tự',
    ),
  ],
);

void main() {
  testWidgets('choosing a file shows the preview summary and every row', (
    tester,
  ) async {
    final fakes = await _openTeachers(tester);
    expect(find.text('Nhập danh sách giảng viên'), findsOneWidget);
    expect(find.textContaining('teacher_id'), findsOneWidget);
    await _pick(tester);

    expect(fakes.admin.imports, [
      (kind: 'teachers', classId: null, file: 'data.csv', dryRun: true),
    ]);
    expect(find.text('Tổng: 3 dòng'), findsOneWidget);
    expect(find.text('Sẽ tạo: 2'), findsOneWidget);
    expect(find.text('Bỏ qua: 1'), findsOneWidget);
    expect(find.text('Lỗi: 0'), findsOneWidget);
    expect(find.text('Dòng 2'), findsOneWidget);
    expect(find.text('Đã ở trong lớp'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận nhập'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'confirming imports once even if tapped twice, then refreshes the data',
    (tester) async {
      final fakes = _fakes();
      await _openTeachers(tester, fakes);
      await _pick(tester);
      final before = fakes.admin.teachersCalls;
      final gate = Completer<ImportReport>();
      fakes.admin.onImport = (kind, classId, file, dryRun) {
        if (dryRun) return Future.value(sampleImportReport());
        return gate.future;
      };

      final confirm = find.widgetWithText(FilledButton, 'Xác nhận nhập');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();
      gate.complete(sampleImportReport(dryRun: false, committed: true));
      await tester.pumpAndSettle();

      expect(fakes.admin.imports.where((i) => !i.dryRun), hasLength(1));
      expect(find.text('Đã nhập 2 dòng'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(fakes.admin.teachersCalls, greaterThan(before));
    },
  );

  testWidgets('a preview with errors blocks the confirmation', (tester) async {
    final fakes = _fakes();
    fakes.admin.onImport = (_, _, _, dryRun) async => _withError();
    await _openTeachers(tester, fakes);
    await _pick(tester);
    expect(find.text('Lỗi: 1'), findsOneWidget);
    expect(
      find.text('Mã giảng viên phải dài từ 3 đến 16 ký tự'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận nhập'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a preview that would create nothing blocks the confirmation', (
    tester,
  ) async {
    final fakes = _fakes();
    fakes.admin.onImport = (_, _, _, _) async => sampleImportReport(
      rows: const [
        ImportRow(
          row: 2,
          status: ImportRowStatus.skipped,
          message: 'Đã tồn tại',
        ),
      ],
    );
    await _openTeachers(tester, fakes);
    await _pick(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận nhập'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('cancelling the file picker does nothing', (tester) async {
    final fakes = _fakes();
    fakes.chooser.next = null;
    await _openTeachers(tester, fakes);
    await _pick(tester);
    expect(fakes.chooser.calls, 1);
    expect(fakes.admin.imports, isEmpty);
    expect(find.textContaining('Tổng:'), findsNothing);
  });

  testWidgets(
    'a wrong extension or a huge file is rejected before any upload',
    (tester) async {
      final fakes = _fakes();
      fakes.chooser.next = PickedFile(name: 'data.txt', bytes: const [1]);
      await _openTeachers(tester, fakes);
      await _pick(tester);
      expect(find.text('Chỉ hỗ trợ file .csv hoặc .xlsx'), findsOneWidget);

      fakes.chooser.next = PickedFile(
        name: 'big.csv',
        bytes: List.filled(2000001, 65),
      );
      await _pick(tester);
      expect(find.text('File quá lớn (tối đa 2 MB)'), findsOneWidget);
      expect(fakes.admin.imports, isEmpty);
    },
  );

  testWidgets('a server error is shown and another file can be chosen', (
    tester,
  ) async {
    final fakes = _fakes();
    var calls = 0;
    fakes.admin.onImport = (_, _, _, dryRun) async {
      calls++;
      if (calls == 1) {
        throw ApiException('missing_columns', 'Thiếu cột: teacher_id');
      }
      return sampleImportReport();
    };
    await _openTeachers(tester, fakes);
    await _pick(tester);
    expect(find.text('Thiếu cột: teacher_id'), findsOneWidget);
    await _pick(tester);
    expect(find.text('Thiếu cột: teacher_id'), findsNothing);
    expect(find.text('Tổng: 3 dòng'), findsOneWidget);
  });

  testWidgets(
    'a commit that the server did not apply is reported as a failure',
    (tester) async {
      final fakes = _fakes();
      fakes.admin.onImport = (_, _, _, dryRun) async =>
          sampleImportReport(dryRun: dryRun, committed: false);
      await _openTeachers(tester, fakes);
      await _pick(tester);
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận nhập');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa được ghi'), findsOneWidget);
      expect(find.text('Đã nhập 2 dòng'), findsNothing);
    },
  );

  testWidgets('the template can be downloaded and shared', (tester) async {
    final fakes = await _openTeachers(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tải file mẫu'));
    await tester.pumpAndSettle();
    expect(fakes.admin.templates, ['teachers']);
    expect(fakes.sharer.shared.single.filename, 'teachers_template.csv');
  });

  testWidgets('the classes import is reachable from the classes tab', (
    tester,
  ) async {
    final fakes = _fakes();
    await openApp(tester, fakes: fakes, role: AppRole.admin, tab: 'Lớp học');
    await tester.tap(find.text('Nhập môn/lớp từ file'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập danh sách môn và lớp'), findsOneWidget);
    await _pick(tester);
    expect(fakes.admin.imports.single.kind, 'classes');
  });

  testWidgets('the students import carries the class id', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fakes = _fakes();
    await openApp(tester, fakes: fakes, role: AppRole.admin, tab: 'Lớp học');
    await tester.tap(find.text('PRM393 · SE1901 · FA26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập danh sách sinh viên'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập danh sách sinh viên'), findsWidgets);
    await _pick(tester);
    expect(fakes.admin.imports.single.kind, 'students');
    expect(fakes.admin.imports.single.classId, 'c1');
  });

  testWidgets('the students tab offers the import for the chosen class', (
    tester,
  ) async {
    final fakes = _fakes();
    await openApp(tester, fakes: fakes, role: AppRole.admin, tab: 'Sinh viên');
    await tester.tap(find.byKey(const Key('students-class')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PRM393 · SE1901').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Nhập danh sách sinh viên'),
    );
    await tester.pumpAndSettle();
    await _pick(tester);
    expect(fakes.admin.imports.single.classId, 'c1');
  });
}
