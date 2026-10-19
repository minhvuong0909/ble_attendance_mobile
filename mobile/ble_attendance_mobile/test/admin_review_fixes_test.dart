import 'dart:async';

import 'package:ble_attendance_mobile/data/file_chooser.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/auth_user.dart';
import 'package:ble_attendance_mobile/models/class_info.dart';
import 'package:ble_attendance_mobile/models/course.dart';
import 'package:ble_attendance_mobile/models/import_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Fakes _fakes() {
  final fakes = Fakes();
  fakes.admin.onTeachers = () async => [
    sampleTeacher(),
    sampleTeacher(id: 't2', teacherId: 'T002', name: 'Thay Nam'),
  ];
  fakes.admin.onCourses = () async => [sampleCourse()];
  fakes.admin.onAllClasses = () async => [sampleClass(joinCode: 'ABC123')];
  fakes.classes.onStudents = (_) async => [];
  return fakes;
}

void main() {
  testWidgets(
    'a failed second file replaces the old preview so it cannot be confirmed',
    (tester) async {
      final fakes = _fakes();
      await openApp(
        tester,
        fakes: fakes,
        role: AppRole.admin,
        tab: 'Giảng viên',
      );
      await tester.tap(find.text('Nhập từ file'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Chọn file'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Xác nhận nhập'),
        findsOneWidget,
      );

      fakes.chooser.next = PickedFile(name: 'wrong.txt', bytes: const [1]);
      await tester.tap(find.widgetWithText(FilledButton, 'Chọn file'));
      await tester.pumpAndSettle();

      expect(find.text('Chỉ hỗ trợ file .csv hoặc .xlsx'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Xác nhận nhập'), findsNothing);
      expect(find.textContaining('Tổng:'), findsNothing);
    },
  );

  testWidgets('cancelling the picker keeps the current preview', (
    tester,
  ) async {
    final fakes = _fakes();
    await openApp(tester, fakes: fakes, role: AppRole.admin, tab: 'Giảng viên');
    await tester.tap(find.text('Nhập từ file'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Chọn file'));
    await tester.pumpAndSettle();
    fakes.chooser.next = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Chọn file'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng: 3 dòng'), findsOneWidget);
  });

  testWidgets('a rejected commit shows the report the server returned', (
    tester,
  ) async {
    final fakes = _fakes();
    fakes.admin.onImport = (_, _, _, dryRun) async => dryRun
        ? sampleImportReport()
        : sampleImportReport(
            dryRun: false,
            committed: false,
            rows: const [
              ImportRow(
                row: 5,
                status: ImportRowStatus.error,
                message: 'Mã bị trùng trong lúc nhập',
              ),
            ],
          );
    await openApp(tester, fakes: fakes, role: AppRole.admin, tab: 'Giảng viên');
    await tester.tap(find.text('Nhập từ file'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Chọn file'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Xác nhận nhập');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Mã bị trùng trong lúc nhập'), findsOneWidget);
    expect(find.textContaining('chưa được ghi'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận nhập'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('system Back cannot close the course dialog while it is saving', (
    tester,
  ) async {
    final fakes = _fakes();
    final gate = Completer<Course>();
    fakes.admin.onCreateCourse = (_, _, _) => gate.future;
    await openApp(tester, fakes: fakes, role: AppRole.admin);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Thêm môn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course-code')), 'PRM101');
    await tester.enterText(find.byKey(const Key('course-name')), 'Nhập môn');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      find.byKey(const Key('course-code')),
      findsOneWidget,
      reason: 'still open while saving',
    );

    final before = fakes.admin.coursesCalls;
    gate.complete(sampleCourse());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('course-code')), findsNothing);
    expect(find.text('Đã thêm môn học'), findsOneWidget);
    expect(fakes.admin.coursesCalls, greaterThan(before));
  });

  testWidgets(
    'system Back cannot close the teacher dialog while it is saving',
    (tester) async {
      final fakes = _fakes();
      final gate = Completer<AuthUser>();
      fakes.admin.onCreateTeacher = (_, _) => gate.future;
      await openApp(
        tester,
        fakes: fakes,
        role: AppRole.admin,
        tab: 'Giảng viên',
      );
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Thêm giảng viên'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('teacher-id')), 'T009');
      await tester.enterText(find.byKey(const Key('teacher-name')), 'Co Hoa');
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo'));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const Key('teacher-id')), findsOneWidget);

      gate.complete(sampleTeacher(id: 't9', teacherId: 'T009', name: 'Co Hoa'));
      await tester.pumpAndSettle();
      expect(find.text('Đã tạo tài khoản'), findsOneWidget);
    },
  );

  testWidgets('system Back cannot close the assign dialog while it is saving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fakes = _fakes();
    final gate = Completer<ClassInfo>();
    fakes.admin.onAssign = (_, _) => gate.future;
    await openApp(tester, fakes: fakes, role: AppRole.admin, tab: 'Lớp học');
    await tester.tap(find.text('PRM393 · SE1901 · FA26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi giảng viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thay Nam · T002'));
    await tester.tap(find.widgetWithText(FilledButton, 'Phân công'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Chọn giảng viên'), findsOneWidget);

    final before = fakes.admin.classesCalls;
    gate.complete(sampleClass());
    await tester.pumpAndSettle();
    expect(find.text('Chọn giảng viên'), findsNothing);
    expect(find.text('Đã phân công giảng viên'), findsOneWidget);
    expect(fakes.admin.classesCalls, greaterThan(before));
  });
}
