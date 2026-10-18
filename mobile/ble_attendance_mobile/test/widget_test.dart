// Kiểm tra ứng dụng khởi động đến màn hình đăng nhập khi chưa có phiên.

import 'package:ble_attendance_mobile/app/app.dart';
import 'package:ble_attendance_mobile/providers/core_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/memory_token_store.dart';

void main() {
  testWidgets('App starts at the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Điểm danh BLE'), findsWidgets);
  });
}
