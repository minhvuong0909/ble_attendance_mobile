import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/pump_app.dart';

Future<void> _openRegister(WidgetTester tester) async {
  await tester.tap(find.text('Chưa có tài khoản? Đăng ký (sinh viên)'));
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String name = 'Nguyen Van A',
  String id = '25ce099',
  String password = 'Pass@123',
  String confirm = 'Pass@123',
}) async {
  await tester.enterText(find.byKey(const Key('register-name')), name);
  await tester.enterText(find.byKey(const Key('register-id')), id);
  await tester.enterText(find.byKey(const Key('register-password')), password);
  await tester.enterText(find.byKey(const Key('register-confirm')), confirm);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
  await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a short password is blocked before any request', (tester) async {
    final repo = FakeAuthRepository();
    String? sent;
    repo.onRegister = (n, id, p) async {
      sent = id;
      return testUser();
    };
    await pumpApp(tester, repo: repo);
    await _openRegister(tester);
    await _fill(tester, password: '12345', confirm: '12345');
    await _submit(tester);
    expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
    expect(sent, isNull);
  });

  testWidgets('mismatching confirmation is blocked', (tester) async {
    await pumpApp(tester);
    await _openRegister(tester);
    await _fill(tester, confirm: 'Khac@123');
    await _submit(tester);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
  });

  testWidgets('empty name and id are blocked', (tester) async {
    await pumpApp(tester);
    await _openRegister(tester);
    await _fill(tester, name: '', id: '');
    await _submit(tester);
    expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
    expect(find.text('Vui lòng nhập mã sinh viên'), findsOneWidget);
  });

  testWidgets('a valid registration signs in and lands on the student home', (tester) async {
    final repo = FakeAuthRepository();
    String? registeredId;
    repo.onRegister = (n, id, p) async {
      registeredId = id;
      return testUser();
    };
    await pumpApp(tester, repo: repo);
    await _openRegister(tester);
    await _fill(tester);
    await _submit(tester);
    expect(registeredId, '25CE099');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a server error is shown and the user stays on the form', (tester) async {
    final repo = FakeAuthRepository()
      ..onRegister = (n, id, p) async =>
          throw ApiException('student_exists', 'Mã sinh viên đã tồn tại', statusCode: 409);
    await pumpApp(tester, repo: repo);
    await _openRegister(tester);
    await _fill(tester);
    await _submit(tester);
    expect(find.text('Mã sinh viên đã tồn tại'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
