import 'package:ble_attendance_mobile/app/app.dart';
import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:ble_attendance_mobile/providers/core_providers.dart';
import 'package:ble_attendance_mobile/providers/retry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'memory_token_store.dart';

/// Chạy toàn bộ [App] với repository và kho token giả, chờ qua màn hình splash.
Future<void> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? repo,
  MemoryTokenStore? store,
  ApiClient? api,
  List<Override> extra = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        tokenStoreProvider.overrideWithValue(store ?? MemoryTokenStore()),
        authRepositoryProvider.overrideWithValue(repo ?? FakeAuthRepository()),
        if (api != null) apiClientProvider.overrideWithValue(api),
        ...extra,
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}
