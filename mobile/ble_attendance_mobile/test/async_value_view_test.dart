import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(AsyncValue<List<String>> value, {VoidCallback? onRetry}) =>
    MaterialApp(
      home: Scaffold(
        body: AsyncValueView<List<String>>(
          value: value,
          onRetry: onRetry ?? () {},
          isEmpty: (items) => items.isEmpty,
          emptyMessage: 'Không có gì',
          emptyIcon: Icons.inbox,
          data: (items) => Column(children: [for (final i in items) Text(i)]),
        ),
      ),
    );

void main() {
  testWidgets('loading shows a progress indicator', (tester) async {
    await tester.pumpWidget(_host(const AsyncLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('data is rendered', (tester) async {
    await tester.pumpWidget(_host(const AsyncData(['a', 'b'])));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('empty data shows the empty message', (tester) async {
    await tester.pumpWidget(_host(const AsyncData([])));
    expect(find.text('Không có gì'), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsOneWidget);
  });

  testWidgets('errors show the friendly message and a retry button', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      _host(
        AsyncError(ApiException('network', 'Mất kết nối'), StackTrace.empty),
        onRetry: () => retried++,
      ),
    );
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retried, 1);
  });
}
