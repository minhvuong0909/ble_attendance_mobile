import 'package:flutter/material.dart';

/// Khung báo thành công, cùng dáng với [ErrorBanner].
class SuccessBanner extends StatelessWidget {
  const SuccessBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
