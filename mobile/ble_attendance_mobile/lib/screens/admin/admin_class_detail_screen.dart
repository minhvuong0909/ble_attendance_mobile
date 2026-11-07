import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../models/auth_user.dart';
import '../../models/class_info.dart';
import '../../models/student_info.dart';
import '../../providers/admin_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/error_banner.dart';
import 'class_form_screen.dart';

class AdminClassDetailScreen extends ConsumerWidget {
  const AdminClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(adminClassesProvider);
    final info = classes.value?.where((c) => c.id == classId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(info?.title ?? 'Chi tiết lớp')),
      body: info == null
          ? AsyncValueView<List<ClassInfo>>(
              value: classes,
              onRetry: () => ref.invalidate(adminClassesProvider),
              isEmpty: (_) => true,
              emptyMessage: 'Không tìm thấy lớp',
              data: (_) => const SizedBox(),
            )
          : _Detail(info: info),
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.info});

  final ClassInfo info;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  final _formKey = GlobalKey<FormState>();
  late final _codeCtrl = TextEditingController(text: widget.info.classCode);
  late final _semesterCtrl = TextEditingController(text: widget.info.semester);
  late final _absenceCtrl = TextEditingController(
    text: '${widget.info.maxAbsencePercent}',
  );
  late final _rssiCtrl = TextEditingController(
    text: '${widget.info.rssiThreshold}',
  );
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _semesterCtrl.dispose();
    _absenceCtrl.dispose();
    _rssiCtrl.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    final info = widget.info;
    final code = _codeCtrl.text.trim().toUpperCase();
    final semester = _semesterCtrl.text.trim();
    final absence = int.parse(_absenceCtrl.text.trim());
    final rssi = int.parse(_rssiCtrl.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    final changed =
        code != info.classCode ||
        semester != info.semester ||
        absence != info.maxAbsencePercent ||
        rssi != info.rssiThreshold;
    if (!changed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không có thay đổi')),
      );
      return;
    }
    await _guard(() async {
      await ref
          .read(adminRepositoryProvider)
          .updateClass(
            info.id,
            classCode: code == info.classCode ? null : code,
            semester: semester == info.semester ? null : semester,
            maxAbsencePercent: absence == info.maxAbsencePercent
                ? null
                : absence,
            rssiThreshold: rssi == info.rssiThreshold ? null : rssi,
          );
      ref.invalidate(adminClassesProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã lưu cấu hình lớp')),
      );
    });
  }

  Future<void> _assign() async {
    final messenger = ScaffoldMessenger.of(context);
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignDialog(
        current: widget.info.teacherUserId,
        onAssign: (teacherId) => ref
            .read(adminRepositoryProvider)
            .assignTeacher(widget.info.id, teacherId),
      ),
    );
    if (assigned == true) {
      ref.invalidate(adminClassesProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã phân công giảng viên')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lớp học?'),
        content: Text(
          'Lớp ${widget.info.title} sẽ bị xóa. Chỉ xóa được khi lớp chưa có sinh viên và buổi học.',
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
    if (confirmed != true || !mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _guard(() async {
      await ref.read(adminRepositoryProvider).deleteClass(widget.info.id);
      ref.invalidate(adminClassesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa lớp')));
      router.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final theme = Theme.of(context);
    final students = ref.watch(classStudentsProvider(info.id));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.courseName, style: theme.textTheme.titleLarge),
                Text('${info.title} · ${info.semester}'),
                const SizedBox(height: 8),
                Text('Giảng viên: ${info.teacherName ?? 'Chưa phân công'}'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _assign,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(
                    info.teacherName == null
                        ? 'Phân công giảng viên'
                        : 'Đổi giảng viên',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Cấu hình lớp', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('setting-code'),
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Mã lớp'),
                    validator: validateClassCode,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('setting-semester'),
                    controller: _semesterCtrl,
                    decoration: const InputDecoration(labelText: 'Học kỳ'),
                    validator: validateSemester,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('setting-absence'),
                    controller: _absenceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mức vắng tối đa (%)',
                    ),
                    validator: validateAbsence,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('setting-rssi'),
                    controller: _rssiCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Ngưỡng tín hiệu RSSI (dBm)',
                    ),
                    validator: validateRssi,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _saveSettings,
                    child: const Text('Lưu cấu hình'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sinh viên (${info.studentCount})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              context.push('/admin/import/students?classId=${info.id}'),
          icon: const Icon(Icons.upload_file),
          label: const Text('Nhập danh sách sinh viên'),
        ),
        const SizedBox(height: 8),
        _StudentsSection(
          value: students,
          onRetry: () => ref.invalidate(classStudentsProvider(info.id)),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Xóa lớp'),
        ),
      ],
    );
  }
}

class _StudentsSection extends StatelessWidget {
  const _StudentsSection({required this.value, required this.onRetry});

  final AsyncValue<List<StudentInfo>> value;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final students = value.value!;
      if (students.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Chưa có sinh viên nào trong lớp'),
        );
      }
      return Column(
        children: [
          for (final s in students)
            ListTile(
              dense: true,
              title: Text('${s.studentId ?? '-'} · ${s.fullName}'),
            ),
        ],
      );
    }
    if (value.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Text(friendlyError(value.error ?? '')),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    );
  }
}

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.current, required this.onAssign});

  final String? current;
  final Future<void> Function(String teacherId) onAssign;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  late String? _selected = widget.current;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final teacherId = _selected;
    if (_busy || teacherId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAssign(teacherId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachers = ref.watch(adminTeachersProvider);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Chọn giảng viên'),
        content: SizedBox(
          width: double.maxFinite,
          child: AsyncValueView<List<AuthUser>>(
            value: teachers,
            onRetry: () => ref.invalidate(adminTeachersProvider),
            isEmpty: (items) => items.isEmpty,
            emptyMessage: 'Chưa có giảng viên nào',
            data: (items) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioGroup<String>(
                    groupValue: _selected,
                    onChanged: (v) {
                      if (!_busy) setState(() => _selected = v);
                    },
                    child: Column(
                      children: [
                        for (final t in items)
                          RadioListTile<String>(
                            value: t.id,
                            title: Text('${t.fullName} · ${t.loginId}'),
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(_error!),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _busy || _selected == null ? null : _submit,
            child: const Text('Phân công'),
          ),
        ],
      ),
    );
  }
}
