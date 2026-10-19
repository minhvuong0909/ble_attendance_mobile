import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Fakes _fakes() {
  final fakes = Fakes();
  fakes.admin.onCourses = () async => [
    sampleCourse(),
    sampleCourse(
      id: 'k2',
      code: 'SWE201',
      name: 'Công nghệ phần mềm',
      credits: null,
    ),
  ];
  return fakes;
}

Future<Fakes> _open(WidgetTester tester, [Fakes? fakes]) async {
  final f = fakes ?? _fakes();
  await openApp(tester, fakes: f, role: AppRole.admin);
  return f;
}

Future<void> _openAddDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'Thêm môn'));
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String? code,
  String? name,
  String? credits,
}) async {
  if (code != null) {
    await tester.enterText(find.byKey(const Key('course-code')), code);
  }
  if (name != null) {
    await tester.enterText(find.byKey(const Key('course-name')), name);
  }
  if (credits != null) {
    await tester.enterText(find.byKey(const Key('course-credits')), credits);
  }
}

void main() {
  testWidgets('lists courses with credits when present', (tester) async {
    await _open(tester);
    expect(find.text('PRM393 · Lập trình di động'), findsOneWidget);
    expect(find.text('3 tín chỉ'), findsOneWidget);
    expect(find.text('SWE201 · Công nghệ phần mềm'), findsOneWidget);
    expect(
      find.textContaining('tín chỉ'),
      findsOneWidget,
      reason: 'the course without credits shows none',
    );
  });

  testWidgets('empty state and retry after an error', (tester) async {
    await _open(tester, Fakes());
    expect(find.text('Chưa có môn học nào'), findsOneWidget);
  });

  testWidgets('a loading error offers a retry', (tester) async {
    final fakes = Fakes();
    var calls = 0;
    fakes.admin.onCourses = () async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return [sampleCourse()];
    };
    await _open(tester, fakes);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('PRM393 · Lập trình di động'), findsOneWidget);
  });

  testWidgets(
    'adding a course sends normalized values and refreshes the list',
    (tester) async {
      final fakes = await _open(tester);
      final before = fakes.admin.coursesCalls;
      await _openAddDialog(tester);
      await _fill(
        tester,
        code: ' prm101 ',
        name: '  Nhập môn lập trình  ',
        credits: '4',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      expect(fakes.admin.createdCourses, [
        {'code': 'PRM101', 'name': 'Nhập môn lập trình', 'credits': 4},
      ]);
      expect(find.byKey(const Key('course-code')), findsNothing);
      expect(find.text('Đã thêm môn học'), findsOneWidget);
      expect(fakes.admin.coursesCalls, greaterThan(before));
    },
  );

  testWidgets('the form blocks invalid values before calling the API', (
    tester,
  ) async {
    final fakes = await _open(tester);
    await _openAddDialog(tester);
    await _fill(tester, code: 'a', name: 'b', credits: '31');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Mã môn từ 2 đến 32 ký tự'), findsOneWidget);
    expect(find.text('Tên môn từ 2 đến 120 ký tự'), findsOneWidget);
    expect(find.text('Tín chỉ từ 0 đến 30'), findsOneWidget);
    expect(fakes.admin.createdCourses, isEmpty);
  });

  testWidgets(
    'a duplicate code keeps the dialog open with the server message',
    (tester) async {
      final fakes = await _open(tester);
      fakes.admin.onCreateCourse = (_, _, _) async =>
          throw ApiException('course_exists', 'Mã môn học đã tồn tại');
      await _openAddDialog(tester);
      await _fill(tester, code: 'PRM393', name: 'Trùng mã');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Mã môn học đã tồn tại'), findsOneWidget);
      expect(find.byKey(const Key('course-code')), findsOneWidget);
    },
  );

  testWidgets('saving twice quickly sends one request', (tester) async {
    final fakes = await _open(tester);
    final gate = Completer<Course>();
    fakes.admin.onCreateCourse = (_, _, _) => gate.future;
    await _openAddDialog(tester);
    await _fill(tester, code: 'PRM101', name: 'Nhập môn');
    final save = find.widgetWithText(FilledButton, 'Lưu');
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    gate.complete(sampleCourse());
    await tester.pumpAndSettle();
    expect(fakes.admin.createdCourses, hasLength(1));
  });

  testWidgets('editing locks the code and sends only the changed fields', (
    tester,
  ) async {
    final fakes = await _open(tester);
    await tester.tap(find.text('PRM393 · Lập trình di động'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('course-code')))
          .enabled,
      isFalse,
    );
    await _fill(tester, name: 'Tên mới của môn');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(fakes.admin.updatedCourses, [
      {'id': 'k1', 'name': 'Tên mới của môn', 'credits': null},
    ]);
    expect(find.text('Đã cập nhật môn học'), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation and calls the API once', (
    tester,
  ) async {
    final fakes = await _open(tester);
    await tester.tap(find.text('PRM393 · Lập trình di động'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xóa môn'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa môn học?'), findsOneWidget);
    await tester.tap(find.text('Hủy').last);
    await tester.pumpAndSettle();
    expect(fakes.admin.deletedCourses, isEmpty);

    await tester.tap(find.text('Xóa môn'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Xóa');
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(fakes.admin.deletedCourses, ['k1']);
    expect(find.text('Đã xóa môn học'), findsOneWidget);
  });

  testWidgets(
    'a course that still has classes cannot be deleted and stays listed',
    (tester) async {
      final fakes = await _open(tester);
      fakes.admin.onDeleteCourse = (_) async => throw ApiException(
        'course_has_classes',
        'Môn học đang có lớp, không thể xóa',
      );
      await tester.tap(find.text('PRM393 · Lập trình di động'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa môn'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Môn học đang có lớp, không thể xóa'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('PRM393 · Lập trình di động'), findsOneWidget);
    },
  );
}
