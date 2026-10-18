import 'package:flutter/material.dart';

class WarningBanner extends StatelessWidget {
  const WarningBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFEF6C00);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
