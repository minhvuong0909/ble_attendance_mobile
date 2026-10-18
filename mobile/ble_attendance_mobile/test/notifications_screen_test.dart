import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/providers/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fakes.dart';
import 'helpers/memory_token_store.dart';
import 'helpers/pump_app.dart';

Future<FakeNotificationRepository> _open(
  WidgetTester tester, {
  FakeNotificationRepository? repo,
  AppRole role = AppRole.student,
}) async {
  final notifications = repo ?? FakeNotificationRepository();
  final auth = FakeAuthRepository()..onMe = () async => testUser(role: role);
  await pumpApp(
    tester,
    repo: auth,
    store: MemoryTokenStore(token: 't'),
    extra: [
      notificationRepositoryProvider.overrideWithValue(notifications),
      classRepositoryProvider.overrideWithValue(FakeClassRepository()),
      sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
      statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
      leaveRepositoryProvider.overrideWithValue(FakeLeaveRepository()),
    ],
  );
  if (role != AppRole.admin) {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Thông báo'),
      ),
    );
    await tester.pumpAndSettle();
  }
  return notifications;
}

FontWeight? _weightOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.fontWeight;

void main() {
  testWidgets('lists notifications in server order with unread ones in bold', (
    tester,
  ) async {
    final repo = FakeNotificationRepository()
      ..onList = () async => [
        sampleNotification(id: 2, title: 'Chưa đọc'),
        sampleNotification(id: 1, title: 'Đã đọc', isRead: true),
      ];
    await _open(tester, repo: repo);
    expect(find.text('Chưa đọc'), findsOneWidget);
    expect(find.text('Đã đọc'), findsOneWidget);
    expect(_weightOf(tester, 'Chưa đọc'), FontWeight.bold);
    expect(_weightOf(tester, 'Đã đọc'), isNot(FontWeight.bold));
    expect(
      tester.getTopLeft(find.text('Chưa đọc')).dy,
      lessThan(tester.getTopLeft(find.text('Đã đọc')).dy),
    );
  });

  testWidgets('tapping an unread notification marks it read', (tester) async {
    final repo = FakeNotificationRepository()
      ..onList = () async => [sampleNotification(id: 5, title: 'Mới')];
    await _open(tester, repo: repo);
    await tester.tap(find.text('Mới'));
    await tester.pumpAndSettle();
    expect(repo.markedRead, [5]);
    expect(_weightOf(tester, 'Mới'), isNot(FontWeight.bold));
  });

  testWidgets('a failed mark-read is reverted and reported', (tester) async {
    final repo = FakeNotificationRepository();
    repo.onList = () async => [sampleNotification(id: 5, title: 'Mới')];
    repo.onMarkRead = (_) async => throw ApiException('network', 'Mất kết nối');
    await _open(tester, repo: repo);
    await tester.tap(find.text('Mới'));
    await tester.pumpAndSettle();
    expect(_weightOf(tester, 'Mới'), FontWeight.bold);
    expect(find.text('Mất kết nối'), findsOneWidget);
  });

  testWidgets('read-all calls the repository and clears the unread marks', (
    tester,
  ) async {
    final repo = FakeNotificationRepository()
      ..onList = () async => [
        sampleNotification(id: 1, title: 'A'),
        sampleNotification(id: 2, title: 'B'),
      ];
    await _open(tester, repo: repo);
    await tester.tap(find.text('Đọc tất cả'));
    await tester.pumpAndSettle();
    expect(repo.markAllCalls, 1);
    expect(_weightOf(tester, 'A'), isNot(FontWeight.bold));
    expect(find.text('Đọc tất cả'), findsNothing);
  });

  testWidgets('empty state', (tester) async {
    await _open(tester);
    expect(find.text('Chưa có thông báo'), findsOneWidget);
  });

  testWidgets('error state offers a retry that reloads', (tester) async {
    var calls = 0;
    final repo = FakeNotificationRepository()
      ..onList = () async {
        calls++;
        if (calls == 1) throw ApiException('network', 'Mất kết nối');
        return [sampleNotification(title: 'Đã tải được')];
      };
    await _open(tester, repo: repo);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Đã tải được'), findsOneWidget);
  });

  testWidgets(
    'the tab shows an unread badge, hidden at zero and capped at 99+',
    (tester) async {
      for (final entry in {5: '5', 150: '99+'}.entries) {
        final repo = FakeNotificationRepository()
          ..onUnreadCount = () async => entry.key;
        await _open(tester, repo: repo);
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(entry.value),
          ),
          findsOneWidget,
          reason: 'count ${entry.key}',
        );
        await tester.pumpWidget(const SizedBox());
      }

      await _open(tester);
      expect(find.byType(Badge), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the unread count is refreshed every 30 seconds', (tester) async {
    var count = 1;
    final repo = FakeNotificationRepository()
      ..onUnreadCount = () async => count;
    await _open(tester, repo: repo);
    final before = repo.countCalls;
    count = 4;
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(repo.countCalls, greaterThan(before));
    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('4')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admins have no notifications tab', (tester) async {
    await _open(tester, role: AppRole.admin);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Thông báo'),
      ),
      findsNothing,
    );
  });
}
