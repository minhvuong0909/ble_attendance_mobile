import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../providers/leave_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/error_banner.dart';

const _minRssi = -100;
const _maxRssi = -30;
const _presets = [('Nhỏ', -70), ('Vừa', -75), ('Lớn', -85)];

/// Mở hộp thoại chỉnh ngưỡng RSSI của lớp; trả true nếu đã lưu.
Future<bool?> showRssiDialog(
  BuildContext context, {
  required String classId,
  required int current,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _RssiDialog(classId: classId, current: current),
);

class _RssiDialog extends ConsumerStatefulWidget {
  const _RssiDialog({required this.classId, required this.current});

  final String classId;
  final int current;

  @override
  ConsumerState<_RssiDialog> createState() => _RssiDialogState();
}

class _RssiDialogState extends ConsumerState<_RssiDialog> {
  late final _ctrl = TextEditingController(text: '${widget.current}');
  bool _busy = false;
  String? _fieldError;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    final value = int.tryParse(text);
    if (value == null || value < _minRssi || value > _maxRssi) {
      setState(() => _fieldError = 'Ngưỡng RSSI từ -100 đến -30');
      return;
    }
    setState(() {
      _busy = true;
      _fieldError = null;
      _error = null;
    });
    try {
      await ref.read(classRepositoryProvider).updateRssi(widget.classId, value);
      ref.invalidate(myClassListProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ngưỡng RSSI của lớp'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sinh viên được tính là ở trong lớp khi tín hiệu mạnh hơn ngưỡng này. '
              'Phòng nhỏ dùng -70, phòng lớn dùng -85 (càng âm càng chấp nhận ngồi xa). '
              'Áp dụng cho buổi học bắt đầu sau khi lưu.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (index, (label, value)) in _presets.indexed) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      labelPadding: EdgeInsets.zero,
                      label: Center(child: Text('$label $value')),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _ctrl.text = '$value';
                              _fieldError = null;
                            }),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('rssi-field'),
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: 'Ngưỡng RSSI (dBm)',
                errorText: _fieldError,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Lưu')),
      ],
    );
  }
}
