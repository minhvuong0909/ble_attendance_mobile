import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/memory_token_store.dart';

ApiClient _client(MemoryTokenStore store, FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    store: store,
    dio: dio,
    defaultBaseUrl: 'http://default:8000',
  );
}

void main() {
  _lateResponses();
  test('adds the bearer header when a token is stored', () async {
    final adapter = FakeAdapter((_) async => jsonBody({'ok': true}));
    final client = _client(MemoryTokenStore(token: 'abc'), adapter);
    await client.get('/health');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer abc');
  });

  test('sends no Authorization header without a token', () async {
    final adapter = FakeAdapter((_) async => jsonBody({'ok': true}));
    final client = _client(MemoryTokenStore(), adapter);
    await client.get('/health');
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('401 clears the token and notifies', () async {
    final adapter = FakeAdapter(
      (_) async =>
          jsonBody({'detail': 'x', 'code': 'invalid_token'}, status: 401),
    );
    final store = MemoryTokenStore(token: 'stale');
    final client = _client(store, adapter);
    var notified = 0;
    client.onUnauthorized = () => notified++;

    await expectLater(client.get('/auth/me'), throwsA(isA<ApiException>()));
    expect(store.token, isNull);
    expect(notified, 1);
  });

  test('401 from /auth/login does not clear the token or notify', () async {
    final adapter = FakeAdapter(
      (_) async => jsonBody({
        'detail': 'Sai mật khẩu',
        'code': 'invalid_credentials',
      }, status: 401),
    );
    final store = MemoryTokenStore(token: 'keep');
    final client = _client(store, adapter);
    var notified = 0;
    client.onUnauthorized = () => notified++;

    await expectLater(
      client.post('/auth/login', data: {'identifier': 'a', 'password': 'b'}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'invalid_credentials',
        ),
      ),
    );
    expect(store.token, 'keep');
    expect(notified, 0);
  });

  test('backend errors become ApiException with code and message', () async {
    final adapter = FakeAdapter(
      (_) async => jsonBody({
        'detail': 'Mã đã tồn tại',
        'code': 'student_exists',
      }, status: 409),
    );
    final client = _client(MemoryTokenStore(), adapter);
    await expectLater(
      client.post('/auth/register', data: {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'student_exists')
            .having((e) => e.message, 'message', 'Mã đã tồn tại'),
      ),
    );
  });

  test('connection failures become a network ApiException', () async {
    final adapter = FakeAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final client = _client(MemoryTokenStore(), adapter);
    await expectLater(
      client.get('/health'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'network')),
    );
  });

  test('successful calls return decoded JSON', () async {
    final adapter = FakeAdapter((_) async => jsonBody({'status': 'ok'}));
    final client = _client(MemoryTokenStore(), adapter);
    expect(await client.get('/health'), {'status': 'ok'});
  });

  test('uses the default base url until one is saved', () async {
    final client = _client(
      MemoryTokenStore(),
      FakeAdapter((_) async => jsonBody({})),
    );
    await client.init();
    expect(client.baseUrl, 'http://default:8000');
  });

  test('setBaseUrl normalizes, persists and is restored by init', () async {
    final store = MemoryTokenStore();
    final first = _client(store, FakeAdapter((_) async => jsonBody({})));
    await first.setBaseUrl('192.168.1.9:8000/');
    expect(first.baseUrl, 'http://192.168.1.9:8000');
    expect(first.dio.options.baseUrl, 'http://192.168.1.9:8000');
    expect(store.baseUrl, 'http://192.168.1.9:8000');

    final second = _client(store, FakeAdapter((_) async => jsonBody({})));
    await second.init();
    expect(second.baseUrl, 'http://192.168.1.9:8000');
  });

  test(
    'setBaseUrl rejects an invalid address without changing anything',
    () async {
      final store = MemoryTokenStore();
      final client = _client(store, FakeAdapter((_) async => jsonBody({})));
      await expectLater(client.setBaseUrl('  '), throwsA(isA<ApiException>()));
      expect(client.baseUrl, 'http://default:8000');
      expect(store.baseUrl, isNull);
    },
  );
}

void _lateResponses() {
  test(
    'a late 401 from a request sent with an old token does not sign out a new session',
    () async {
      final gate = Completer<void>();
      final adapter = FakeAdapter((options) async {
        await gate.future;
        return jsonBody({'detail': 'x', 'code': 'invalid_token'}, status: 401);
      });
      final store = MemoryTokenStore(token: 'T1');
      final client = _client(store, adapter);
      var notified = 0;
      client.onUnauthorized = () => notified++;

      final pending = client.get('/sessions/active');
      while (adapter.requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      store.token =
          'T2'; // người dùng đăng xuất rồi đăng nhập lại trong lúc request đang chạy
      gate.complete();

      await expectLater(pending, throwsA(isA<ApiException>()));
      expect(store.token, 'T2');
      expect(notified, 0);
    },
  );

  test(
    'ping checks /health on the given address without saving it or sending the token',
    () async {
      final adapter = FakeAdapter((_) async => jsonBody({'status': 'ok'}));
      final store = MemoryTokenStore(token: 'secret');
      final client = _client(store, adapter);

      await client.ping('10.0.0.5:8000/');

      expect(
        adapter.requests.single.uri.toString(),
        'http://10.0.0.5:8000/health',
      );
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(store.baseUrl, isNull);
      expect(client.baseUrl, 'http://default:8000');
    },
  );
}
