import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:ble_attendance_mobile/screens/auth/server_settings_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/memory_token_store.dart';
import 'helpers/pump_app.dart';

Future<FakeAdapter> _openSettings(
  WidgetTester tester, {
  required FakeHandler handler,
  MemoryTokenStore? store,
}) async {
  final adapter = FakeAdapter(handler);
  final theStore = store ?? MemoryTokenStore();
  final api = ApiClient(
    store: theStore,
    dio: Dio()..httpClientAdapter = adapter,
    defaultBaseUrl: 'http://192.168.1.7:8000',
  );
  await pumpApp(
    tester,
    store: theStore,
    api: api,
    extra: [
      wakeConfigProvider.overrideWithValue(
        const WakeConfig(interval: Duration(milliseconds: 10), attempts: 5),
      ),
    ],
  );
  await tester.tap(find.byTooltip('Cài đặt máy chủ'));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets('shows the current address', (tester) async {
    await _openSettings(
      tester,
      handler: (_) async => jsonBody({'status': 'ok'}),
    );
    final field = tester.widget<TextField>(find.byKey(const Key('server-url')));
    expect(field.controller!.text, 'http://192.168.1.7:8000');
  });

  testWidgets('an invalid address is rejected with a message', (tester) async {
    await _openSettings(
      tester,
      handler: (_) async => jsonBody({'status': 'ok'}),
    );
    await tester.enterText(find.byKey(const Key('server-url')), '   ');
    await tester.tap(find.text('Kiểm tra kết nối'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập địa chỉ máy chủ.'), findsOneWidget);
  });

  testWidgets('a successful connection test is reported', (tester) async {
    final adapter = await _openSettings(
      tester,
      handler: (_) async => jsonBody({'status': 'ok'}),
    );
    await tester.enterText(
      find.byKey(const Key('server-url')),
      '10.0.0.5:8000',
    );
    await tester.tap(find.text('Kiểm tra kết nối'));
    await tester.pumpAndSettle();
    expect(find.text('Kết nối thành công'), findsOneWidget);
    expect(adapter.requests.last.uri.toString(), 'http://10.0.0.5:8000/health');
  });

  testWidgets('testing a connection does not persist the address until Lưu', (
    tester,
  ) async {
    final store = MemoryTokenStore();
    await _openSettings(
      tester,
      handler: (_) async => jsonBody({'status': 'ok'}),
      store: store,
    );
    await tester.enterText(
      find.byKey(const Key('server-url')),
      '10.0.0.5:8000',
    );
    await tester.tap(find.text('Kiểm tra kết nối'));
    await tester.pumpAndSettle();
    expect(store.baseUrl, isNull);
  });

  testWidgets('a failed connection test shows the network message', (
    tester,
  ) async {
    await _openSettings(
      tester,
      handler: (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    await tester.tap(find.text('Kiểm tra kết nối'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
  });

  testWidgets('saving normalizes and stores the address', (tester) async {
    final store = MemoryTokenStore();
    await _openSettings(
      tester,
      handler: (_) async => jsonBody({'status': 'ok'}),
      store: store,
    );
    await tester.enterText(
      find.byKey(const Key('server-url')),
      ' 10.0.0.5:8000/ ',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(store.baseUrl, 'http://10.0.0.5:8000');
  });

  testWidgets('wake-up retries until the server answers, then stops', (
    tester,
  ) async {
    var calls = 0;
    final adapter = await _openSettings(
      tester,
      handler: (options) async {
        calls++;
        if (calls < 3) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonBody({'status': 'ok'});
      },
    );
    await tester.ensureVisible(find.text('Đánh thức máy chủ (Render)'));
    await tester.tap(find.text('Đánh thức máy chủ (Render)'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ đã sẵn sàng'), findsOneWidget);
    expect(adapter.requests.length, 3);
  });

  testWidgets('wake-up gives up after the configured attempts', (tester) async {
    final adapter = await _openSettings(
      tester,
      handler: (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    await tester.ensureVisible(find.text('Đánh thức máy chủ (Render)'));
    await tester.tap(find.text('Đánh thức máy chủ (Render)'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(adapter.requests.length, 5);
    expect(find.textContaining('Máy chủ chưa phản hồi'), findsOneWidget);
  });
}
