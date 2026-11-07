import 'dart:convert';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/core/device_id.dart';
import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:ble_attendance_mobile/data/auth_repository.dart';
import 'package:ble_attendance_mobile/providers/auth_controller.dart';
import 'package:ble_attendance_mobile/providers/core_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/fake_auth_repository.dart';
import 'helpers/memory_token_store.dart';
import 'helpers/pump_app.dart';

ApiException _mismatch() => ApiException(
  'device_mismatch',
  'Tài khoản đã gắn với một thiết bị khác. Hãy gửi đơn đổi thiết bị cho admin',
  statusCode: 403,
);

void main() {
  group('device id', () {
    test('is 32 hex characters and differs between calls', () {
      final a = newDeviceId();
      final b = newDeviceId();
      expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(a, isNot(b));
    });
  });

  group('repository', () {
    late FakeAdapter adapter;
    late ApiAuthRepository repo;

    setUp(() {
      adapter = FakeAdapter((options) async {
        if (options.path == '/auth/login') {
          return jsonBody({
            'access_token': 'jwt',
            'must_change_password': false,
          });
        }
        return jsonBody({'id': 1, 'status': 'pending'}, status: 201);
      });
      repo = ApiAuthRepository(
        ApiClient(
          store: MemoryTokenStore(),
          dio: Dio()..httpClientAdapter = adapter,
          defaultBaseUrl: 'http://x',
        ),
      );
    });

    test('login sends device_id when given', () async {
      await repo.login('25CE099', 'Pass@123', deviceId: 'abc123');
      expect(jsonDecode(jsonEncode(adapter.requests.single.data)), {
        'identifier': '25CE099',
        'password': 'Pass@123',
        'device_id': 'abc123',
      });
    });

    test('requestDeviceChange posts the request', () async {
      await repo.requestDeviceChange(
        identifier: '25CE099',
        password: 'Pass@123',
        deviceId: 'abc123',
        reason: 'Đổi điện thoại',
      );
      final request = adapter.requests.single;
      expect(request.path, '/auth/device-change-requests');
      expect(jsonDecode(jsonEncode(request.data)), {
        'identifier': '25CE099',
        'password': 'Pass@123',
        'device_id': 'abc123',
        'reason': 'Đổi điện thoại',
      });
    });
  });

  group('controller', () {
    ({
      ProviderContainer container,
      FakeAuthRepository repo,
      MemoryTokenStore store,
    })
    setup() {
      final repo = FakeAuthRepository();
      final store = MemoryTokenStore();
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, repo: repo, store: store);
    }

    test(
      'creates a device id on first login, stores it and reuses it',
      () async {
        final s = setup();
        final controller = s.container.read(authControllerProvider.notifier);
        await controller.login('25CE099', 'Pass@123');
        final first = s.repo.loginDeviceIds.single;
        expect(first, isNotNull);
        expect(s.store.deviceId, first);

        await controller.logout();
        await controller.login('25CE099', 'Pass@123');
        expect(s.repo.loginDeviceIds.last, first);
      },
    );

    test('requestDeviceChange sends the stored device id', () async {
      final s = setup();
      s.store.deviceId = 'my-device-1';
      await s.container
          .read(authControllerProvider.notifier)
          .requestDeviceChange(
            id: ' 25ce099 ',
            password: 'Pass@123',
            reason: 'Mất máy',
          );
      expect(s.repo.deviceChangeRequests.single.identifier, '25CE099');
      expect(s.repo.deviceChangeRequests.single.deviceId, 'my-device-1');
      expect(s.repo.deviceChangeRequests.single.reason, 'Mất máy');
    });
  });

  group('login screen', () {
    Future<void> fillAndSubmit(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('login-id')), '25CE099');
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'Pass@123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers a change request when the device does not match', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..onLogin = (id, password) async => throw _mismatch();
      await pumpApp(tester, repo: repo);
      expect(find.text('Gửi đơn đổi thiết bị'), findsNothing);
      await fillAndSubmit(tester);
      expect(find.textContaining('gắn với một thiết bị khác'), findsOneWidget);
      expect(find.text('Gửi đơn đổi thiết bị'), findsOneWidget);
    });

    testWidgets('does not offer it for other errors', (tester) async {
      final repo = FakeAuthRepository()
        ..onLogin = (id, password) async => throw ApiException(
          'invalid_credentials',
          'Sai mật khẩu',
          statusCode: 401,
        );
      await pumpApp(tester, repo: repo);
      await fillAndSubmit(tester);
      expect(find.text('Sai mật khẩu'), findsOneWidget);
      expect(find.text('Gửi đơn đổi thiết bị'), findsNothing);
    });

    testWidgets('sends the request with the reason and confirms', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..onLogin = (id, password) async => throw _mismatch();
      final store = MemoryTokenStore(deviceId: 'new-phone-id');
      await pumpApp(tester, repo: repo, store: store);
      await fillAndSubmit(tester);

      await tester.tap(find.text('Gửi đơn đổi thiết bị'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('device-reason')),
        'Đổi điện thoại mới',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Gửi đơn'));
      await tester.pumpAndSettle();

      expect(repo.deviceChangeRequests.single.reason, 'Đổi điện thoại mới');
      expect(repo.deviceChangeRequests.single.deviceId, 'new-phone-id');
      expect(find.textContaining('Đã gửi đơn'), findsOneWidget);
    });

    testWidgets('requires a reason before sending', (tester) async {
      final repo = FakeAuthRepository()
        ..onLogin = (id, password) async => throw _mismatch();
      await pumpApp(tester, repo: repo);
      await fillAndSubmit(tester);
      await tester.tap(find.text('Gửi đơn đổi thiết bị'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Gửi đơn'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do'), findsOneWidget);
      expect(repo.deviceChangeRequests, isEmpty);
    });

    testWidgets('shows the server error when the request fails', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      repo.onLogin = (id, password) async => throw _mismatch();
      repo.onRequestDeviceChange = (a, b, c, d) async => throw ApiException(
        'invalid_credentials',
        'Sai mã đăng nhập hoặc mật khẩu',
        statusCode: 401,
      );
      await pumpApp(tester, repo: repo);
      await fillAndSubmit(tester);
      await tester.tap(find.text('Gửi đơn đổi thiết bị'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('device-reason')), 'Đổi máy');
      await tester.tap(find.widgetWithText(FilledButton, 'Gửi đơn'));
      await tester.pumpAndSettle();
      expect(find.text('Sai mã đăng nhập hoặc mật khẩu'), findsOneWidget);
    });
  });
}
