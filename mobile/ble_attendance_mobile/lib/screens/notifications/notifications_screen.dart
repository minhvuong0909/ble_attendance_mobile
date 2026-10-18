import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../models/app_notification.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/async_value_view.dart';

IconData _iconFor(String type) => switch (type) {
  'finalization_open' => Icons.how_to_reg,
  'leave_submitted' => Icons.event_note,
  'leave_reviewed' => Icons.fact_check,
  'absence_warning' => Icons.warning_amber,
  _ => Icons.notifications,
};

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(notificationsProvider);
    final controller = ref.read(notificationsProvider.notifier);
    return AsyncValueView<List<AppNotification>>(
      value: value,
      onRetry: () => ref.invalidate(notificationsProvider),
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Chưa có thông báo',
      emptyIcon: Icons.notifications_none,
      data: (items) {
        final hasUnread = items.any((n) => !n.isRead);
        return Column(
          children: [
            if (hasUnread)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _run(context, controller.markAllRead),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Đọc tất cả'),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.reload,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Icon(_iconFor(item.type)),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${item.body}\n${formatDateTime(item.createdAt)}',
                      ),
                      isThreeLine: true,
                      trailing: item.isRead
                          ? null
                          : Icon(
                              Icons.circle,
                              size: 10,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      onTap: item.isRead
                          ? null
                          : () => _run(
                              context,
                              () => controller.markRead(item.id),
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
