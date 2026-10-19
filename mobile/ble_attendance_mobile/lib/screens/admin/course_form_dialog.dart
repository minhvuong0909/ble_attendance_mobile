import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/course.dart';
import '../../widgets/error_banner.dart';

enum CourseDialogResult { saved, deleted }

/// Thêm hoặc sửa một môn học. Khi sửa, mã môn chỉ đọc và có nút "Xóa môn".
class CourseFormDialog extends StatefulWidget {
  const CourseFormDialog({
    super.key,
    this.course,
    required this.onSave,
    this.onDelete,
  });

  final Course? course;
  final Future<void> Function(String code, String name, int? credits) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<CourseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _codeCtrl = TextEditingController(text: widget.course?.code ?? '');
  late final _nameCtrl = TextEditingController(text: widget.course?.name ?? '');
  late final _creditsCtrl = TextEditingController(
    text: widget.course?.credits?.toString() ?? '',
  );
  bool _busy = false;
  String? _error;

  bool get _editing => widget.course != null;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _creditsCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action,
    CourseDialogResult result,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final credits = _creditsCtrl.text.trim().isEmpty
        ? null
        : int.parse(_creditsCtrl.text.trim());
    await _run(
      () => widget.onSave(
        _codeCtrl.text.trim().toUpperCase(),
        _nameCtrl.text.trim(),
        credits,
      ),
      CourseDialogResult.saved,
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa môn học?'),
        content: Text(
          'Môn ${widget.course!.code} sẽ bị xóa. Chỉ xóa được khi môn chưa có lớp nào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(widget.onDelete!, CourseDialogResult.deleted);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(_editing ? 'Sửa môn học' : 'Thêm môn học'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('course-code'),
                  controller: _codeCtrl,
                  enabled: !_editing,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã môn',
                    helperText: 'Ví dụ PRM393',
                  ),
                  validator: (v) {
                    final length = (v ?? '').trim().length;
                    return length < 2 || length > 32
                        ? 'Mã môn từ 2 đến 32 ký tự'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('course-name'),
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên môn'),
                  validator: (v) {
                    final length = (v ?? '').trim().length;
                    return length < 2 || length > 120
                        ? 'Tên môn từ 2 đến 120 ký tự'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('course-credits'),
                  controller: _creditsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tín chỉ (không bắt buộc)',
                  ),
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return null;
                    final value = int.tryParse(text);
                    return value == null || value < 0 || value > 30
                        ? 'Tín chỉ từ 0 đến 30'
                        : null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(_error!),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (_editing && widget.onDelete != null)
            TextButton(
              onPressed: _busy ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Xóa môn'),
            ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
