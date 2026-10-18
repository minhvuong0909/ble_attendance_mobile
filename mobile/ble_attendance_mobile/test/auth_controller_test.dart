import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/providers/auth_controller.dart';
import 'package:ble_attendance_mobile/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/memory_token_store.dart';

({ProviderContainer container, FakeAuthRepository repo, MemoryTokenStore store}) _setup({
  String? token,
}) {
  final repo = FakeAuthRepository();
  final store = MemoryTokenStore(token: token);
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, repo: repo, store: store);
}

AuthController _controller(ProviderContainer c) => c.read(authControllerProvider.notifier);
AuthState _state(ProviderContainer c) => c.read(authControllerProvider);

void main() {
  test('starts in the unknown state', () {
    final s = _setup();
    expect(_state(s.container).status, AuthStatus.unknown);
  });

  test('bootstrap without a token is unauthenticated', () async {
    final s = _setup();
    await _controller(s.container).bootstrap();
    expect(_state(s.container).status, AuthStatus.unauthenticated);
  });

  test('bootstrap with a valid token loads the user', () async {
    final s = _setup(token: 'good');
    await _controller(s.container).bootstrap();
    expect(_state(s.container).status, AuthStatus.authenticated);
    expect(_state(s.container).user?.loginId, '25CE099');
  });

  test('bootstrap with an expired token clears it and ends unauthenticated', () async {
    final s = _setup(token: 'expired');
    s.repo.onMe = () async => throw ApiException('invalid_token', 'Hết hạn', statusCode: 401);
    await _controller(s.container).bootstrap();
    expect(_state(s.container).status, AuthStatus.unauthenticated);
    expect(s.store.token, isNull);
  });

  test('bootstrap while offline keeps the token and does not hang', () async {
    final s = _setup(token: 'maybe-good');
    s.repo.onMe = () async => throw ApiException('network', 'Mất mạng');
    await _controller(s.container).bootstrap();
    expect(_state(s.container).status, AuthStatus.unauthenticated);
    expect(s.store.token, 'maybe-good');
  });

  test('login normalizes the id, stores the token and loads the user', () async {
    final s = _setup();
    await _controller(s.container).login('  25ce099 ', 'Pass@123');
    expect(s.repo.loginIds, ['25CE099']);
    expect(s.store.token, 'token-25CE099');
    expect(_state(s.container).status, AuthStatus.authenticated);
  });

  test('failed login throws and leaves state and token untouched', () async {
    final s = _setup();
    s.repo.onLogin = (id, password) async =>
        throw ApiException('invalid_credentials', 'Sai mật khẩu', statusCode: 401);
    await expectLater(
      _controller(s.container).login('25CE099', 'sai'),
      throwsA(isA<ApiException>()),
    );
    expect(s.store.token, isNull);
    expect(_state(s.container).status, AuthStatus.unknown);
  });

  test('login that fails while loading the user removes the fresh token', () async {
    final s = _setup();
    s.repo.onMe = () async => throw ApiException('network', 'Mất mạng');
    await expectLater(
      _controller(s.container).login('25CE099', 'Pass@123'),
      throwsA(isA<ApiException>()),
    );
    expect(s.store.token, isNull);
    expect(_state(s.container).status, isNot(AuthStatus.authenticated));
  });

  test('register creates the account then signs in', () async {
    final s = _setup();
    String? registeredId;
    s.repo.onRegister = (name, id, password) async {
      registeredId = id;
      return testUser(name: name);
    };
    await _controller(s.container).register(
      fullName: 'Nguyen Van A',
      identifier: '25ce099',
      password: 'Pass@123',
    );
    expect(registeredId, '25CE099');
    expect(_state(s.container).status, AuthStatus.authenticated);
  });

  test('changePassword refreshes the user and clears the forced-change flag', () async {
    final s = _setup();
    s.repo.onMe = () async => testUser(mustChangePassword: true);
    await _controller(s.container).login('25CE099', 'Pass@123');
    expect(_state(s.container).user!.mustChangePassword, isTrue);

    s.repo.onMe = () async => testUser(mustChangePassword: false);
    await _controller(s.container).changePassword(oldPassword: 'a', newPassword: 'bbbbbb');
    expect(_state(s.container).user!.mustChangePassword, isFalse);
  });

  test('logout clears the token and the user', () async {
    final s = _setup();
    await _controller(s.container).login('25CE099', 'Pass@123');
    await _controller(s.container).logout();
    expect(s.store.token, isNull);
    expect(_state(s.container).status, AuthStatus.unauthenticated);
    expect(_state(s.container).user, isNull);
  });

  test('a 401 reported by ApiClient signs the user out', () async {
    final s = _setup();
    await _controller(s.container).login('25CE099', 'Pass@123');
    s.container.read(apiClientProvider).onUnauthorized!();
    expect(_state(s.container).status, AuthStatus.unauthenticated);
  });
}
