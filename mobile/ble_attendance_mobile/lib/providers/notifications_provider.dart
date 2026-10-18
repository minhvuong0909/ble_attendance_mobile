import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import 'repositories.dart';

const _unreadPollInterval = Duration(seconds: 30);

/// Số thông báo chưa đọc, tự làm mới mỗi 30 giây khi còn có widget theo dõi.
final unreadCountProvider =
    NotifierProvider.autoDispose<UnreadCountNotifier, int>(
      UnreadCountNotifier.new,
    );

class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() {
    final timer = Timer.periodic(_unreadPollInterval, (_) => refresh());
    ref.onDispose(timer.cancel);
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      final count = await ref
          .read(notificationRepositoryProvider)
          .unreadCount();
      if (ref.mounted) state = count;
    } catch (_) {
      // Giữ số cũ khi mất mạng; lần làm mới sau sẽ thử lại.
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      List<AppNotification>
    >(NotificationsController.new);

class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() =>
      ref.read(notificationRepositoryProvider).list();

  Future<void> reload() async {
    state = await AsyncValue.guard(
      ref.read(notificationRepositoryProvider).list,
    );
    ref.read(unreadCountProvider.notifier).refresh();
  }

  /// Cập nhật lạc quan, hoàn lại và ném lỗi nếu server không nhận.
  Future<void> markRead(int id) async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData([
      for (final n in before) n.id == id ? n.copyWith(isRead: true) : n,
    ]);
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
      ref.read(unreadCountProvider.notifier).refresh();
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData([for (final n in before) n.copyWith(isRead: true)]);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      ref.read(unreadCountProvider.notifier).refresh();
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}
