import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/app_role.dart';
import '../providers/auth_controller.dart';
import '../screens/auth/change_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/server_settings_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/shell/placeholder_tab.dart';
import '../screens/shell/shell_tabs.dart';

/// Quyết định chuyển hướng theo trạng thái đăng nhập. Trả null nếu giữ nguyên vị trí.
String? authRedirect(AuthState auth, String location) {
  final path = Uri.parse(location).path;
  if (path == '/settings') return null;

  switch (auth.status) {
    case AuthStatus.unknown:
      return path == '/splash' ? null : '/splash';
    case AuthStatus.unauthenticated:
      return (path == '/login' || path == '/register') ? null : '/login';
    case AuthStatus.authenticated:
      final user = auth.user!;
      if (user.mustChangePassword) {
        return path == '/change-password' ? null : '/change-password';
      }
      if (path == '/change-password') return null;
      final home = user.role.homePath;
      if (path == home || path.startsWith('$home/')) return null;
      return home;
  }
}

StatefulShellRoute _shellFor(AppRole role) {
  final tabs = tabsFor(role);
  return StatefulShellRoute.indexedStack(
    builder: (context, state, shell) =>
        AppShell(navigationShell: shell, role: role),
    branches: [
      for (final tab in tabs)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: tab.path,
              builder: (context, state) =>
                  PlaceholderTab(title: tab.label, icon: tab.icon),
            ),
          ],
        ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  // Chỉ làm mới router khi dữ liệu mà authRedirect dựa vào thay đổi. Làm mới thừa sẽ
  // đặt lại ngăn xếp trang (ví dụ nuốt mất thao tác pop sau khi đổi mật khẩu tự nguyện).
  ref.listen(authControllerProvider, (previous, next) {
    final changed =
        previous?.status != next.status ||
        previous?.user?.role != next.user?.role ||
        previous?.user?.mustChangePassword != next.user?.mustChangePassword;
    if (changed) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.uri.toString()),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/change-password',
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const ServerSettingsScreen(),
      ),
      for (final role in AppRole.values) _shellFor(role),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
