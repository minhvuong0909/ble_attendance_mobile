import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';

/// Hiển thị một [AsyncValue] với đủ 3 trạng thái: đang tải, lỗi (thử lại) và rỗng.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.isEmpty,
    this.emptyMessage = 'Không có dữ liệu',
    this.emptyIcon = Icons.inbox_outlined,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Centered(
        icon: Icons.error_outline,
        message: friendlyError(error),
        action: FilledButton.tonal(
          onPressed: onRetry,
          child: const Text('Thử lại'),
        ),
      ),
      data: (items) {
        if (isEmpty?.call(items) ?? false) {
          return _Centered(icon: emptyIcon, message: emptyMessage);
        }
        return data(items);
      },
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
