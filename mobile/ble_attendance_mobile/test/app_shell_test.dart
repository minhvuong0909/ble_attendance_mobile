import 'package:ble_attendance_mobile/app/app.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/providers/auth_controller.dart';
import 'package:ble_attendance_mobile/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/memory_token_store.dart';

/// Controller cố định trạng thái ban đầu; logout vẫn chạy thật.
class FixedAuthController extends AuthController {
  FixedAuthController(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

Future<void> _pump(WidgetTester tester, AuthState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(MemoryTokenStore(token: 'abc')),
        authControllerProvider.overrideWith(() => FixedAuthController(state)),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

AuthState _signedIn(AppRole role) => AuthState(
  status: AuthStatus.authenticated,
  user: testUser(role: role),
);

void main() {
  const labels = {
    AppRole.student: ['Trang chủ', 'Lớp của tôi', 'Xin phép', 'Thông báo'],
    AppRole.teacher: ['Lớp học', 'Buổi trực tiếp', 'Xin phép', 'Thông báo'],
    AppRole.admin: ['Môn học', 'Lớp học', 'Giảng viên', 'Sinh viên'],
  };

  for (final role in AppRole.values) {
    testWidgets('${role.name} sees its four tabs and can switch', (
      tester,
    ) async {
      await _pump(tester, _signedIn(role));
      final bar = find.byType(NavigationBar);
      expect(bar, findsOneWidget);
      for (final label in labels[role]!) {
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsOneWidget,
        );
      }

      final second = labels[role]![1];
      await tester.tap(find.descendant(of: bar, matching: find.text(second)));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(second)),
        findsOneWidget,
      );
    });
  }

  testWidgets('a wide window uses a side rail and keeps the tabs working', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, _signedIn(AppRole.admin));
    expect(find.byType(NavigationBar), findsNothing);
    final rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    for (final label in labels[AppRole.admin]!) {
      expect(
        find.descendant(of: rail, matching: find.text(label)),
        findsOneWidget,
      );
    }
    await tester.tap(find.descendant(of: rail, matching: find.text('Lớp học')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Lớp học')),
      findsOneWidget,
    );
  });

  testWidgets('content is limited to a readable width on huge windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, _signedIn(AppRole.admin));
    final box = tester.getSize(find.byKey(const Key('app-frame')));
    expect(box.width, lessThanOrEqualTo(1280));
  });

  testWidgets('the profile menu shows the user and logs out', (tester) async {
    await _pump(tester, _signedIn(AppRole.student));
    await tester.tap(find.byKey(const Key('profile-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Cài đặt máy chủ'), findsOneWidget);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Điểm danh BLE'), findsWidgets);
  });

  testWidgets('no navigation bar while signed out', (tester) async {
    await _pump(tester, const AuthState(status: AuthStatus.unauthenticated));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Điểm danh BLE'), findsWidgets);
  });
}
