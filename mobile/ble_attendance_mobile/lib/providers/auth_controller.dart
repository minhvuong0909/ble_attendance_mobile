import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/validators.dart';
import '../models/auth_user.dart';
import 'core_providers.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final AuthUser? user;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.read(apiClientProvider).onUnauthorized = _onUnauthorized;
    return const AuthState(status: AuthStatus.unknown);
  }

  void _onUnauthorized() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Khôi phục phiên khi mở app. Mất mạng thì giữ token để lần sau thử lại.
  Future<void> bootstrap() async {
    final store = ref.read(tokenStoreProvider);
    await ref.read(apiClientProvider).init();
    final token = await store.readToken();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await ref.read(authRepositoryProvider).me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await store.clearToken();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String id, String password) async {
    final store = ref.read(tokenStoreProvider);
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(normalizeId(id), password);
    await store.saveToken(result.accessToken);
    try {
      final user = await repo.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      await store.clearToken();
      rethrow;
    }
  }

  Future<void> register({
    required String fullName,
    required String identifier,
    required String password,
  }) async {
    final id = normalizeId(identifier);
    await ref
        .read(authRepositoryProvider)
        .register(
          fullName: fullName.trim(),
          identifier: id,
          password: password,
        );
    await login(id, password);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    final user = await repo.me();
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
