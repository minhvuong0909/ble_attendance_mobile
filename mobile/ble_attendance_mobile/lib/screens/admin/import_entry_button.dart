import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Nút mở màn hình import nằm đầu danh sách.
class ImportEntryButton extends StatelessWidget {
  const ImportEntryButton({super.key, required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => context.push(path),
          icon: const Icon(Icons.upload_file),
          label: Text(label),
        ),
      ),
    );
  }
}
