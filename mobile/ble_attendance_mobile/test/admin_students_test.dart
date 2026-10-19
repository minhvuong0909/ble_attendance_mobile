import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Fakes _fakes() {
  final fakes = Fakes();
  fakes.admin.onAllClasses = () async => [
    sampleClass(),
    sampleClass(id: 'c2', classCode: 'SE1902'),
  ];
  fakes.classes.onStudents = (classId) async => classId == 'c1'
      ? [
          sampleStudent(),
          sampleStudent(id: 'u2', studentId: '25CE100', name: 'Tran Thi B'),
        ]
      : [];
  return fakes;
}

Future<Fakes> _open(WidgetTester tester, [Fakes? fakes]) async {
  final f = fakes ?? _fakes();
  await openApp(tester, fakes: f, role: AppRole.admin, tab: 'Sinh viên');
  return f;
}

Future<void> _choose(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(const Key('students-class')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks to choose a class first', (tester) async {
    await _open(tester);
    expect(find.text('Chọn một lớp để xem sinh viên'), findsOneWidget);
  });

  testWidgets('choosing a class loads its students and changing it reloads', (
    tester,
  ) async {
    await _open(tester);
    await _choose(tester, 'PRM393 · SE1901');
    expect(find.text('25CE099 · Nguyen Van A'), findsOneWidget);
    expect(find.text('25CE100 · Tran Thi B'), findsOneWidget);

    await _choose(tester, 'PRM393 · SE1902');
    expect(find.text('Lớp chưa có sinh viên'), findsOneWidget);
    expect(find.text('25CE099 · Nguyen Van A'), findsNothing);
  });

  testWidgets('no classes at all', (tester) async {
    await _open(tester, Fakes());
    expect(find.text('Chưa có lớp nào'), findsOneWidget);
  });

  testWidgets('a student loading error offers a retry', (tester) async {
    final fakes = _fakes();
    var calls = 0;
    final real = fakes.classes.onStudents;
    fakes.classes.onStudents = (id) async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return real(id);
    };
    await _open(tester, fakes);
    await _choose(tester, 'PRM393 · SE1901');
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('25CE099 · Nguyen Van A'), findsOneWidget);
  });

  testWidgets(
    'resetting a student password asks first, runs once and names the student id',
    (tester) async {
      final fakes = await _open(tester);
      await _choose(tester, 'PRM393 · SE1901');

      await tester.tap(find.byTooltip('Tùy chọn').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt lại mật khẩu?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(fakes.admin.resets, isEmpty);

      await tester.tap(find.byTooltip('Tùy chọn').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Đặt lại');
      await tester.tap(confirm);
      await tester.tap(confirm, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fakes.admin.resets, ['u1']);
      expect(find.textContaining('25CE099, viết hoa'), findsOneWidget);
    },
  );

  testWidgets('a failed reset shows the server message', (tester) async {
    final fakes = await _open(tester);
    fakes.admin.onResetPassword = (_) async =>
        throw ApiException('user_not_found', 'Không tìm thấy người dùng');
    await _choose(tester, 'PRM393 · SE1901');
    await tester.tap(find.byTooltip('Tùy chọn').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt lại mật khẩu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đặt lại'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy người dùng'), findsOneWidget);
  });
}
