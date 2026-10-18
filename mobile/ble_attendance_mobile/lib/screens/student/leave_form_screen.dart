import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../models/class_info.dart';
import '../../providers/leave_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/error_banner.dart';

/// Khoảng ngày được chọn: cho phép xin bù trong 7 ngày qua và xin trước tối đa 90 ngày.
({DateTime first, DateTime last}) leaveDateRange(DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  return (
    first: day.subtract(const Duration(days: 7)),
    last: day.add(const Duration(days: 90)),
  );
}

class LeaveFormScreen extends ConsumerWidget {
  const LeaveFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(myClassListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Xin phép vắng')),
      body: AsyncValueView<List<ClassInfo>>(
        value: classes,
        onRetry: () => ref.invalidate(myClassListProvider),
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Hãy tham gia lớp trước khi xin phép',
        emptyIcon: Icons.school_outlined,
        data: (items) => _LeaveForm(classes: items),
      ),
    );
  }
}

class _LeaveForm extends ConsumerStatefulWidget {
  const _LeaveForm({required this.classes});

  final List<ClassInfo> classes;

  @override
  ConsumerState<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends ConsumerState<_LeaveForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  String? _classId;
  late DateTime _date;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final range = leaveDateRange(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: range.first,
      lastDate: range.last,
      helpText: 'Chọn ngày xin phép',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref
          .read(leaveRepositoryProvider)
          .create(
            classId: _classId!,
            date: _date,
            reason: _reasonCtrl.text.trim(),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã gửi đơn xin phép')),
      );
      router.pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('leave-class'),
              initialValue: _classId,
              decoration: const InputDecoration(labelText: 'Lớp'),
              items: [
                for (final c in widget.classes)
                  DropdownMenuItem(value: c.id, child: Text(c.title)),
              ],
              onChanged: (value) => setState(() => _classId = value),
              validator: (v) => v == null ? 'Vui lòng chọn lớp' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('leave-date'),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ngày xin phép',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(formatDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('leave-reason'),
              controller: _reasonCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Lý do',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Lý do cần ít nhất 3 ký tự'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gửi đơn'),
            ),
          ],
        ),
      ),
    );
  }
}
