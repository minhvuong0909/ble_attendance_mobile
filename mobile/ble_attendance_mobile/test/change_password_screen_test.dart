import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/memory_token_store.dart';
import 'helpers/pump_app.dart';

Future<void> _fill(
  WidgetTester tester, {
  String old = 'Pass@123',
  String next = 'NewPass@456',
  String confirm = 'NewPass@456',
}) async {
  await tester.enterText(find.byKey(const Key('old-password')), old);
  await tester.enterText(find.byKey(const Key('new-password')), next);
  await tester.enterText(find.byKey(const Key('confirm-password')), confirm);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
  await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
  await tester.pumpAndSettle();
}

FakeAuthRepository _forcedRepo() {
  final repo = FakeAuthRepository();
  repo.onMe = () async => testUser(mustChangePassword: true);
  return repo;
}

void main() {
  testWidgets('a forced change cannot be skipped: no back button, only logout', (tester) async {
    await pumpApp(tester, repo: _forcedRepo(), store: MemoryTokenStore(token: 't'));
    expect(find.text('Đổi mật khẩu'), findsWidgets);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Đăng xuất'), findsOneWidget);
  });

  testWidgets('mismatching confirmation is blocked', (tester) async {
    final repo = _forcedRepo();
    var called = false;
    repo.onChangePassword = (o, n) async => called = true;
    await pumpApp(tester, repo: repo, store: MemoryTokenStore(token: 't'));
    await _fill(tester, confirm: 'Khac@123');
    await _submit(tester);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('a wrong current password shows the server message', (tester) async {
    final repo = _forcedRepo()
      ..onChangePassword = (o, n) async =>
          throw ApiException('invalid_password', 'Mật khẩu hiện tại không đúng', statusCode: 400);
    await pumpApp(tester, repo: repo, store: MemoryTokenStore(token: 't'));
    await _fill(tester);
    await _submit(tester);
    expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('after a forced change the user reaches the role home', (tester) async {
    final repo = _forcedRepo();
    repo.onChangePassword = (o, n) async {
      repo.onMe = () async => testUser(mustChangePassword: false);
    };
    await pumpApp(tester, repo: repo, store: MemoryTokenStore(token: 't'));
    await _fill(tester);
    await _submit(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('logout from the forced screen returns to the login screen', (tester) async {
    await pumpApp(tester, repo: _forcedRepo(), store: MemoryTokenStore(token: 't'));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Điểm danh BLE'), findsWidgets);
    expect(find.byKey(const Key('login-id')), findsOneWidget);
  });

  testWidgets('a voluntary change has a back button and returns home with a message', (tester) async {
    await pumpApp(tester, store: MemoryTokenStore(token: 't'));
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await _fill(tester);
    await _submit(tester);
    expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('old-password')), findsNothing);
  });
}
