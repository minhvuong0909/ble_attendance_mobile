import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/export_file.dart';
import '../providers/repositories.dart';

/// Nút xuất Excel: tải tệp rồi mở share sheet. Khóa nút khi đang chạy; lỗi hiện SnackBar.
class ExportButton extends ConsumerStatefulWidget {
  const ExportButton({
    super.key,
    required this.onExport,
    this.label = 'Xuất Excel',
  });

  final Future<ExportFile> Function() onExport;
  final String label;

  @override
  ConsumerState<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<ExportButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await widget.onExport();
      await ref.read(fileSharerProvider).share(file.filename, file.bytes);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download),
      label: Text(widget.label),
    );
  }
}
