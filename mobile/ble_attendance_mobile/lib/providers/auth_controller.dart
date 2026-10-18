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
    try {
      try {
        await ref.read(apiClientProvider).init();
      } on ApiException {
        // Địa chỉ máy chủ đã lưu bị hỏng: dùng địa chỉ mặc định.
      }
      final token = await store.readToken();
      if (token == null || token.isEmpty) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final user = await ref.read(authRepositoryProvider).me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (error) {
      // Mọi lỗi (mất mạng, trang đăng nhập Wi-Fi trả HTML, lỗi kho khóa...) đều phải kết thúc
      // ở màn hình đăng nhập chứ không kẹt ở splash. Chỉ 401 mới xóa token.
      if (error is ApiException && error.statusCode == 401) {
        try {
          await store.clearToken();
        } catch (_) {}
      }
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
    // Đã đổi thành công; nếu làm mới thông tin lỗi thì tự hạ cờ ở máy để không báo lỗi oan.
    try {
      final user = await repo.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      final current = state.user;
      if (current != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: current.copyWith(mustChangePassword: false),
        );
      }
    }
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
