import 'package:ble_attendance_mobile/app/router.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/providers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';

AuthState _signedIn(AppRole role, {bool mustChange = false}) => AuthState(
  status: AuthStatus.authenticated,
  user: testUser(role: role, mustChangePassword: mustChange),
);

const _unknown = AuthState(status: AuthStatus.unknown);
const _signedOut = AuthState(status: AuthStatus.unauthenticated);

void main() {
  group('unknown', () {
    test('everything goes to /splash except /splash and /settings', () {
      expect(authRedirect(_unknown, '/login'), '/splash');
      expect(authRedirect(_unknown, '/student'), '/splash');
      expect(authRedirect(_unknown, '/splash'), isNull);
      expect(authRedirect(_unknown, '/settings'), isNull);
    });
  });

  group('unauthenticated', () {
    test('only login, register and settings are reachable', () {
      expect(authRedirect(_signedOut, '/login'), isNull);
      expect(authRedirect(_signedOut, '/register'), isNull);
      expect(authRedirect(_signedOut, '/settings'), isNull);
      expect(authRedirect(_signedOut, '/splash'), '/login');
      expect(authRedirect(_signedOut, '/student'), '/login');
      expect(authRedirect(_signedOut, '/admin/classes'), '/login');
      expect(authRedirect(_signedOut, '/change-password'), '/login');
    });
  });

  group('authenticated', () {
    test('leaves auth pages for the role home', () {
      for (final role in AppRole.values) {
        final state = _signedIn(role);
        expect(authRedirect(state, '/login'), role.homePath);
        expect(authRedirect(state, '/register'), role.homePath);
        expect(authRedirect(state, '/splash'), role.homePath);
      }
    });

    test('stays inside its own branch', () {
      expect(authRedirect(_signedIn(AppRole.student), '/student'), isNull);
      expect(authRedirect(_signedIn(AppRole.student), '/student/classes'), isNull);
      expect(authRedirect(_signedIn(AppRole.teacher), '/teacher/live'), isNull);
      expect(authRedirect(_signedIn(AppRole.admin), '/admin/teachers'), isNull);
    });

    test('is sent home when it opens another role area', () {
      expect(authRedirect(_signedIn(AppRole.teacher), '/admin'), '/teacher');
      expect(authRedirect(_signedIn(AppRole.student), '/teacher/live'), '/student');
      expect(authRedirect(_signedIn(AppRole.admin), '/student'), '/admin');
      expect(authRedirect(_signedIn(AppRole.student), '/studentx'), '/student');
    });

    test('settings and a voluntary password change stay reachable', () {
      final state = _signedIn(AppRole.teacher);
      expect(authRedirect(state, '/settings'), isNull);
      expect(authRedirect(state, '/change-password'), isNull);
    });

    test('query strings do not confuse the match', () {
      expect(authRedirect(_signedIn(AppRole.student), '/student/classes?x=1'), isNull);
    });
  });

  group('forced password change', () {
    test('every page except settings goes to /change-password', () {
      for (final role in AppRole.values) {
        final state = _signedIn(role, mustChange: true);
        expect(authRedirect(state, role.homePath), '/change-password');
        expect(authRedirect(state, '/login'), '/change-password');
        expect(authRedirect(state, '/admin'), '/change-password');
        expect(authRedirect(state, '/change-password'), isNull);
        expect(authRedirect(state, '/settings'), isNull);
      }
    });
  });
}
