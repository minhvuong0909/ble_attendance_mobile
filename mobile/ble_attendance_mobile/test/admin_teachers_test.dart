import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/auth_user.dart';
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
  return fakes;
}

Future<Fakes> _open(WidgetTester tester, [Fakes? fakes]) async {
  final f = fakes ?? _fakes();
  await openApp(tester, fakes: f, role: AppRole.admin, tab: 'Giảng viên');
  return f;
}

Future<void> _openAdd(WidgetTester tester) async {
  await tester.tap(
    find.widgetWithText(FloatingActionButton, 'Thêm giảng viên'),
  );
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String id = 'T009',
  String name = 'Co Hoa',
}) async {
  await tester.enterText(find.byKey(const Key('teacher-id')), id);
  await tester.enterText(find.byKey(const Key('teacher-name')), name);
}

Future<void> _openMenuReset(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Tùy chọn').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Đặt lại mật khẩu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists teachers with their login ids', (tester) async {
    await _open(tester);
    expect(find.text('Co Lan'), findsOneWidget);
    expect(find.text('T001'), findsOneWidget);
    expect(find.text('Thay Nam'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _open(tester, Fakes());
    expect(find.text('Chưa có giảng viên nào'), findsOneWidget);
  });

  testWidgets('a loading error offers a retry', (tester) async {
    final fakes = _fakes();
    var calls = 0;
    final real = fakes.admin.onTeachers;
    fakes.admin.onTeachers = () async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return real();
    };
    await _open(tester, fakes);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Co Lan'), findsOneWidget);
  });

  testWidgets(
    'creating a teacher normalizes the id and reminds about the temporary password',
    (tester) async {
      final fakes = await _open(tester);
      final before = fakes.admin.teachersCalls;
      await _openAdd(tester);
      await _fill(tester, id: ' t002 ', name: '  Thầy Nam  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Tạo'));
      await tester.pumpAndSettle();

      expect(fakes.admin.createdTeachers, [
        {'teacherId': 'T002', 'fullName': 'Thầy Nam'},
      ]);
      expect(find.text('Đã tạo tài khoản'), findsOneWidget);
      expect(find.textContaining('Mật khẩu tạm'), findsOneWidget);
      expect(find.textContaining('T002'), findsWidgets);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(fakes.admin.teachersCalls, greaterThan(before));
    },
  );

  testWidgets('the form blocks short values', (tester) async {
    final fakes = await _open(tester);
    await _openAdd(tester);
    await _fill(tester, id: 'ab', name: '');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo'));
    await tester.pumpAndSettle();
    expect(find.text('Mã giảng viên từ 3 đến 16 ký tự'), findsOneWidget);
    expect(find.text('Họ tên từ 2 đến 120 ký tự'), findsOneWidget);
    expect(fakes.admin.createdTeachers, isEmpty);
  });

  testWidgets('a duplicate id keeps the dialog open with the server message', (
    tester,
  ) async {
    final fakes = await _open(tester);
    fakes.admin.onCreateTeacher = (_, _) async =>
        throw ApiException('teacher_exists', 'Mã giảng viên đã tồn tại');
    await _openAdd(tester);
    await _fill(tester, id: 'T001');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo'));
    await tester.pumpAndSettle();
    expect(find.text('Mã giảng viên đã tồn tại'), findsOneWidget);
    expect(find.byKey(const Key('teacher-id')), findsOneWidget);
  });

  testWidgets('creating twice quickly sends one request', (tester) async {
    final fakes = await _open(tester);
    final gate = Completer<AuthUser>();
    fakes.admin.onCreateTeacher = (_, _) => gate.future;
    await _openAdd(tester);
    await _fill(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    gate.complete(sampleTeacher());
    await tester.pumpAndSettle();
    expect(fakes.admin.createdTeachers, hasLength(1));
  });

  testWidgets(
    'resetting a password asks for confirmation, runs once and reminds',
    (tester) async {
      final fakes = await _open(tester);
      await _openMenuReset(tester);
      expect(find.text('Đặt lại mật khẩu?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(fakes.admin.resets, isEmpty);

      await _openMenuReset(tester);
      final confirm = find.widgetWithText(FilledButton, 'Đặt lại');
      await tester.tap(confirm);
      await tester.tap(confirm, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fakes.admin.resets, ['t1']);
      expect(find.textContaining('Mật khẩu tạm'), findsOneWidget);
      expect(find.textContaining('T001'), findsWidgets);
    },
  );

  testWidgets('a failed reset shows the server message', (tester) async {
    final fakes = await _open(tester);
    fakes.admin.onResetPassword = (_) async =>
        throw ApiException('user_not_found', 'Không tìm thấy người dùng');
    await _openMenuReset(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Đặt lại'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy người dùng'), findsOneWidget);
  });
}
