import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/class_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Fakes _fakes() {
  final fakes = Fakes();
  fakes.admin.onAllClasses = () async => [
    sampleClass(joinCode: 'ABC123', studentCount: 3),
    sampleClass(
      id: 'c2',
      classCode: 'SE1902',
      joinCode: 'XYZ789',
      studentCount: 0,
    ).copyForTest(teacherName: null),
  ];
  fakes.admin.onCourses = () async => [
    sampleCourse(),
    sampleCourse(id: 'k2', code: 'SWE201', name: 'Công nghệ phần mềm'),
  ];
  fakes.admin.onTeachers = () async => [
    sampleTeacher(),
    sampleTeacher(id: 't2', teacherId: 'T002', name: 'Thay Nam'),
  ];
  fakes.classes.onStudents = (_) async => [
    sampleStudent(),
    sampleStudent(id: 'u2', studentId: '25CE100', name: 'Tran Thi B'),
  ];
  return fakes;
}

extension on ClassInfo {
  ClassInfo copyForTest({String? teacherName}) => ClassInfo(
    id: id,
    courseId: courseId,
    courseCode: courseCode,
    courseName: courseName,
    classCode: classCode,
    semester: semester,
    teacherUserId: teacherName == null ? null : teacherUserId,
    teacherName: teacherName,
    joinCode: joinCode,
    maxAbsencePercent: maxAbsencePercent,
    rssiThreshold: rssiThreshold,
    studentCount: studentCount,
  );
}

Future<Fakes> _open(WidgetTester tester, [Fakes? fakes]) async {
  final f = fakes ?? _fakes();
  await openApp(tester, fakes: f, role: AppRole.admin, tab: 'Lớp học');
  return f;
}

Future<void> _pick(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _openCreate(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'Tạo lớp'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
}

Future<void> _submitCreate(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Tạo lớp'));
  await tester.tap(find.widgetWithText(FilledButton, 'Tạo lớp'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists all classes with teacher, student count and join code', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('PRM393 · SE1901 · FA26'), findsOneWidget);
    expect(find.text('GV: Co Lan'), findsOneWidget);
    expect(find.text('3 sinh viên'), findsOneWidget);
    expect(find.text('Mã lớp ABC123'), findsOneWidget);
    expect(find.text('Chưa phân công giảng viên'), findsOneWidget);
  });

  testWidgets('empty state and an error with retry', (tester) async {
    await _open(tester, Fakes());
    expect(find.text('Chưa có lớp nào'), findsOneWidget);
  });

  testWidgets('a loading error offers a retry', (tester) async {
    final fakes = _fakes();
    var calls = 0;
    final real = fakes.admin.onAllClasses;
    fakes.admin.onAllClasses = () async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return real();
    };
    await _open(tester, fakes);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('PRM393 · SE1901 · FA26'), findsOneWidget);
  });

  testWidgets('creating a class sends the defaults and normalized values', (
    tester,
  ) async {
    final fakes = await _open(tester);
    await _openCreate(tester);
    await _pick(
      tester,
      const Key('class-course'),
      'SWE201 · Công nghệ phần mềm',
    );
    await _type(tester, 'class-code', ' se1905 ');
    await _type(tester, 'class-semester', ' FA26 ');
    await _submitCreate(tester);

    expect(fakes.admin.createdClasses, [
      {
        'courseId': 'k2',
        'classCode': 'SE1905',
        'semester': 'FA26',
        'teacherUserId': null,
        'maxAbsencePercent': 20,
        'rssiThreshold': -75,
      },
    ]);
    expect(find.text('Đã tạo lớp'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Tạo lớp'),
      findsOneWidget,
    );
  });

  testWidgets('a teacher can be chosen when creating a class', (tester) async {
    final fakes = await _open(tester);
    await _openCreate(tester);
    await _pick(
      tester,
      const Key('class-course'),
      'PRM393 · Lập trình di động',
    );
    await _pick(tester, const Key('class-teacher'), 'Thay Nam · T002');
    await _type(tester, 'class-code', 'SE1906');
    await _type(tester, 'class-semester', 'FA26');
    await _type(tester, 'class-absence', '25');
    await _type(tester, 'class-rssi', '-70');
    await _submitCreate(tester);
    expect(fakes.admin.createdClasses.single['teacherUserId'], 't2');
    expect(fakes.admin.createdClasses.single['maxAbsencePercent'], 25);
    expect(fakes.admin.createdClasses.single['rssiThreshold'], -70);
  });

  testWidgets(
    'the create form blocks a missing course and out-of-range values',
    (tester) async {
      final fakes = await _open(tester);
      await _openCreate(tester);
      await _type(tester, 'class-absence', '101');
      await _type(tester, 'class-rssi', '-20');
      await _submitCreate(tester);
      expect(find.text('Vui lòng chọn môn học'), findsOneWidget);
      expect(find.text('Vui lòng nhập mã lớp'), findsOneWidget);
      expect(find.text('Học kỳ từ 2 đến 32 ký tự'), findsOneWidget);
      expect(find.text('Từ 0 đến 100'), findsOneWidget);
      expect(find.text('Từ -100 đến -30'), findsOneWidget);
      expect(fakes.admin.createdClasses, isEmpty);
    },
  );

  testWidgets('without any course the form asks to create one first', (
    tester,
  ) async {
    final fakes = _fakes();
    fakes.admin.onCourses = () async => [];
    await _open(tester, fakes);
    await _openCreate(tester);
    expect(find.text('Hãy tạo môn học trước khi tạo lớp'), findsOneWidget);
  });

  testWidgets('a duplicate class keeps the form open with the server message', (
    tester,
  ) async {
    final fakes = await _open(tester);
    fakes.admin.onCreateClass = (_) async =>
        throw ApiException('class_exists', 'Lớp này đã tồn tại trong học kỳ');
    await _openCreate(tester);
    await _pick(
      tester,
      const Key('class-course'),
      'PRM393 · Lập trình di động',
    );
    await _type(tester, 'class-code', 'SE1901');
    await _type(tester, 'class-semester', 'FA26');
    await _submitCreate(tester);
    expect(find.text('Lớp này đã tồn tại trong học kỳ'), findsOneWidget);
  });

  testWidgets('submitting twice quickly creates one class', (tester) async {
    final fakes = await _open(tester);
    final gate = Completer<ClassInfo>();
    fakes.admin.onCreateClass = (_) => gate.future;
    await _openCreate(tester);
    await _pick(
      tester,
      const Key('class-course'),
      'PRM393 · Lập trình di động',
    );
    await _type(tester, 'class-code', 'SE1907');
    await _type(tester, 'class-semester', 'FA26');
    final button = find.widgetWithText(FilledButton, 'Tạo lớp');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    gate.complete(sampleClass());
    await tester.pumpAndSettle();
    expect(fakes.admin.createdClasses, hasLength(1));
  });

  Future<Fakes> openDetail(WidgetTester tester) async {
    final fakes = await _open(tester);
    await tester.tap(find.text('PRM393 · SE1901 · FA26'));
    await tester.pumpAndSettle();
    return fakes;
  }

  testWidgets(
    'the detail page shows the class, teacher, settings and students',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openDetail(tester);
      expect(find.text('Mã lớp: ABC123'), findsOneWidget);
      expect(find.text('Giảng viên: Co Lan'), findsOneWidget);
      expect(find.text('25CE099 · Nguyen Van A'), findsOneWidget);
      expect(find.text('25CE100 · Tran Thi B'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('setting-absence')))
            .controller!
            .text,
        '20',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('setting-rssi')))
            .controller!
            .text,
        '-75',
      );
    },
  );

  testWidgets('assigning a teacher calls the API with the chosen teacher', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fakes = await openDetail(tester);
    await tester.tap(find.text('Đổi giảng viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thay Nam · T002'));
    await tester.tap(find.widgetWithText(FilledButton, 'Phân công'));
    await tester.pumpAndSettle();
    expect(fakes.admin.assigned, [(classId: 'c1', teacherId: 't2')]);
    expect(find.text('Đã phân công giảng viên'), findsOneWidget);
  });

  testWidgets('an active session blocks reassignment with the server message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fakes = _fakes();
    fakes.admin.onAssign = (_, _) async => throw ApiException(
      'class_has_active_session',
      'Lớp đang có buổi học, chưa thể đổi giảng viên',
    );
    await _open(tester, fakes);
    await tester.tap(find.text('PRM393 · SE1901 · FA26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi giảng viên'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thay Nam · T002'));
    await tester.tap(find.widgetWithText(FilledButton, 'Phân công'));
    await tester.pumpAndSettle();
    expect(
      find.text('Lớp đang có buổi học, chưa thể đổi giảng viên'),
      findsOneWidget,
    );
  });

  testWidgets(
    'saving settings sends only the changed fields and validates ranges',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fakes = await openDetail(tester);
      await tester.enterText(find.byKey(const Key('setting-rssi')), '-20');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu cấu hình'));
      await tester.pumpAndSettle();
      expect(find.text('Từ -100 đến -30'), findsOneWidget);
      expect(fakes.admin.updatedClasses, isEmpty);

      await tester.enterText(find.byKey(const Key('setting-rssi')), '-70');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu cấu hình'));
      await tester.pumpAndSettle();
      expect(fakes.admin.updatedClasses.single['rssiThreshold'], -70);
      expect(fakes.admin.updatedClasses.single['maxAbsencePercent'], isNull);
      expect(fakes.admin.updatedClasses.single['classCode'], isNull);
      expect(find.text('Đã lưu cấu hình lớp'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting a class asks for confirmation and handles a non-empty class',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fakes = _fakes();
      fakes.admin.onDeleteClass = (_) async => throw ApiException(
        'class_not_empty',
        'Lớp đã có sinh viên hoặc buổi học, không thể xóa',
      );
      await _open(tester, fakes);
      await tester.tap(find.text('PRM393 · SE1901 · FA26'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xóa lớp'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa lớp học?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(fakes.admin.deletedClasses, isEmpty);

      await tester.tap(find.text('Xóa lớp'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(fakes.admin.deletedClasses, ['c1']);
      expect(
        find.text('Lớp đã có sinh viên hoặc buổi học, không thể xóa'),
        findsOneWidget,
      );
      expect(
        find.text('Giảng viên: Co Lan'),
        findsOneWidget,
        reason: 'still on the detail page',
      );
    },
  );

  testWidgets('deleting an empty class returns to the list', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fakes = await openDetail(tester);
    await tester.tap(find.text('Xóa lớp'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(fakes.admin.deletedClasses, ['c1']);
    expect(find.text('Đã xóa lớp'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Tạo lớp'),
      findsOneWidget,
    );
  });
}
