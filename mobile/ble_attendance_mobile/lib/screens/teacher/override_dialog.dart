import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/attendance_record.dart';
import '../../models/attendance_status.dart';
import '../../widgets/error_banner.dart';

/// Hộp thoại chỉnh tay điểm danh của một sinh viên. Trả true khi đã lưu thành công.
class OverrideDialog extends StatefulWidget {
  const OverrideDialog({
    super.key,
    required this.record,
    required this.onSubmit,
  });

  final AttendanceRecord record;
  final Future<void> Function(AttendanceStatus status, String reason) onSubmit;

  @override
  State<OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<OverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  late AttendanceStatus _status = widget.record.status;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_status, _reasonCtrl.text.trim());
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
      title: const Text('Chỉnh tay điểm danh'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.record.studentId ?? '-'} · ${widget.record.studentName}',
              ),
              RadioGroup<AttendanceStatus>(
                groupValue: _status,
                onChanged: (value) {
                  if (value != null && !_busy) setState(() => _status = value);
                },
                child: Column(
                  children: [
                    for (final s in AttendanceStatus.values)
                      RadioListTile<AttendanceStatus>(
                        value: s,
                        title: Text(s.label),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              TextFormField(
                key: const Key('override-reason'),
                controller: _reasonCtrl,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Lý do'),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Lý do cần ít nhất 3 ký tự'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                ErrorBanner(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
