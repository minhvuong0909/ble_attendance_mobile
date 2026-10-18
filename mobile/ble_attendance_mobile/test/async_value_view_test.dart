import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/providers/retry.dart';
import 'package:ble_attendance_mobile/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
  _extraCases();
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

final _flaky = FutureProvider.autoDispose<List<String>>((ref) async {
  final calls = ref.watch(_callCount);
  if (calls == 1) return ['a', 'b'];
  if (calls == 2) throw ApiException('network', 'Mất kết nối');
  await Completer<void>().future; // lần 3 trở đi: đang tải mãi
  return [];
});
final _callCount = StateProvider<int>((ref) => 1);

class _Flaky extends ConsumerWidget {
  const _Flaky();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AsyncValueView<List<String>>(
        value: ref.watch(_flaky),
        onRetry: () => ref.read(_callCount.notifier).state++,
        data: (items) => Column(children: [for (final i in items) Text(i)]),
      );
}

void _extraCases() {
  testWidgets('a later error keeps showing the previous data', (tester) async {
    final container = ProviderContainer(retry: noAutoRetry);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: _Flaky())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);

    container.read(_callCount.notifier).state = 2; // lần làm mới tiếp theo lỗi
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(find.text('Mất kết nối'), findsNothing);
  });

  testWidgets('retrying after an error without data shows the spinner again', (
    tester,
  ) async {
    final container = ProviderContainer(retry: noAutoRetry);
    addTearDown(container.dispose);
    container.read(_callCount.notifier).state = 2;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: _Flaky())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
  });

  testWidgets('the empty state supports pull-to-refresh', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncValueView<List<String>>(
            value: const AsyncData([]),
            onRetry: () {},
            onRefresh: () async => refreshed++,
            isEmpty: (items) => items.isEmpty,
            emptyMessage: 'Không có gì',
            data: (items) => const SizedBox(),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    expect(find.text('Không có gì'), findsOneWidget);
  });
}
