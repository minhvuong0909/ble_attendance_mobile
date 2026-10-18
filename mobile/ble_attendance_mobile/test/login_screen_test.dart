import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/memory_token_store.dart';
import 'helpers/pump_app.dart';

Future<void> _fill(WidgetTester tester, String id, String password) async {
  await tester.enterText(find.byKey(const Key('login-id')), id);
  await tester.enterText(find.byKey(const Key('login-password')), password);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'empty fields show validation messages and do not call the server',
    (tester) async {
      final repo = FakeAuthRepository();
      await pumpApp(tester, repo: repo);
      await _submit(tester);
      expect(find.text('Vui lòng nhập mã đăng nhập'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(repo.loginIds, isEmpty);
    },
  );

  testWidgets('a successful login lands on the role home', (tester) async {
    final store = MemoryTokenStore();
    await pumpApp(tester, store: store);
    await _fill(tester, '25CE099', 'Pass@123');
    await _submit(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(store.token, 'token-25CE099');
  });

  testWidgets('the id is normalized before it is sent', (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, repo: repo);
    await _fill(tester, ' 25ce099 ', 'Pass@123');
    await _submit(tester);
    expect(repo.loginIds, ['25CE099']);
  });

  testWidgets(
    'a wrong password shows the server message, stays on login and stores nothing',
    (tester) async {
      final repo = FakeAuthRepository()
        ..onLogin = (id, password) async => throw ApiException(
          'invalid_credentials',
          'Sai mã đăng nhập hoặc mật khẩu',
          statusCode: 401,
        );
      final store = MemoryTokenStore();
      await pumpApp(tester, repo: repo, store: store);
      await _fill(tester, '25CE099', 'sai-mat-khau');
      await _submit(tester);
      expect(find.text('Sai mã đăng nhập hoặc mật khẩu'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(store.token, isNull);
    },
  );

  testWidgets('the button is disabled while the request is running', (
    tester,
  ) async {
    final completer = Completer<LoginResult>();
    final repo = FakeAuthRepository()
      ..onLogin = (id, password) => completer.future;
    await pumpApp(tester, repo: repo);
    await _fill(tester, '25CE099', 'Pass@123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      const LoginResult(accessToken: 'jwt', mustChangePassword: false),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the password can be revealed', (tester) async {
    await pumpApp(tester);
    final field = find.descendant(
      of: find.byKey(const Key('login-password')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).obscureText, isTrue);
    await tester.tap(find.byKey(const Key('toggle-password')));
    await tester.pump();
    expect(tester.widget<EditableText>(field).obscureText, isFalse);
  });

  testWidgets(
    'the gear opens the server settings and the link opens registration',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Cài đặt máy chủ'));
      await tester.pumpAndSettle();
      expect(find.text('Cài đặt máy chủ'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chưa có tài khoản? Đăng ký (sinh viên)'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng ký sinh viên'), findsWidgets);
    },
  );
}
