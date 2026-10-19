import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../models/auth_user.dart';
import '../../models/course.dart';
import '../../providers/admin_providers.dart';
import '../../providers/repositories.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/error_banner.dart';

String? validateAbsence(String? v) {
  final value = int.tryParse((v ?? '').trim());
  return value == null || value < 0 || value > 100 ? 'Từ 0 đến 100' : null;
}

String? validateRssi(String? v) {
  final value = int.tryParse((v ?? '').trim());
  return value == null || value < -100 || value > -30
      ? 'Từ -100 đến -30'
      : null;
}

String? validateSemester(String? v) {
  final length = (v ?? '').trim().length;
  return length < 2 || length > 32 ? 'Học kỳ từ 2 đến 32 ký tự' : null;
}

String? validateClassCode(String? v) {
  final length = (v ?? '').trim().length;
  if (length == 0) return 'Vui lòng nhập mã lớp';
  return length > 32 ? 'Mã lớp tối đa 32 ký tự' : null;
}

class ClassFormScreen extends ConsumerWidget {
  const ClassFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(adminCoursesProvider);
    final teachers = ref.watch(adminTeachersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo lớp')),
      body: AsyncValueView<List<Course>>(
        value: courses,
        onRetry: () => ref.invalidate(adminCoursesProvider),
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Hãy tạo môn học trước khi tạo lớp',
        emptyIcon: Icons.menu_book_outlined,
        data: (items) =>
            _Form(courses: items, teachers: teachers.value ?? const []),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.courses, required this.teachers});

  final List<Course> courses;
  final List<AuthUser> teachers;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();
  final _absenceCtrl = TextEditingController(text: '20');
  final _rssiCtrl = TextEditingController(text: '-75');
  String? _courseId;
  String? _teacherId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _semesterCtrl.dispose();
    _absenceCtrl.dispose();
    _rssiCtrl.dispose();
    super.dispose();
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
          .read(adminRepositoryProvider)
          .createClass(
            courseId: _courseId!,
            classCode: _codeCtrl.text.trim().toUpperCase(),
            semester: _semesterCtrl.text.trim(),
            teacherUserId: _teacherId,
            maxAbsencePercent: int.parse(_absenceCtrl.text.trim()),
            rssiThreshold: int.parse(_rssiCtrl.text.trim()),
          );
      messenger.showSnackBar(const SnackBar(content: Text('Đã tạo lớp')));
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
              key: const Key('class-course'),
              isExpanded: true,
              initialValue: _courseId,
              decoration: const InputDecoration(labelText: 'Môn học'),
              items: [
                for (final c in widget.courses)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.code} · ${c.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _courseId = v),
              validator: (v) => v == null ? 'Vui lòng chọn môn học' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('class-code'),
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Mã lớp',
                helperText: 'Ví dụ SE1901',
              ),
              validator: validateClassCode,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('class-semester'),
              controller: _semesterCtrl,
              decoration: const InputDecoration(
                labelText: 'Học kỳ',
                helperText: 'Ví dụ FA26',
              ),
              validator: validateSemester,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: const Key('class-teacher'),
              isExpanded: true,
              initialValue: _teacherId,
              decoration: const InputDecoration(
                labelText: 'Giảng viên (không bắt buộc)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Chưa phân công'),
                ),
                for (final t in widget.teachers)
                  DropdownMenuItem<String?>(
                    value: t.id,
                    child: Text(
                      '${t.fullName} · ${t.loginId}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _teacherId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('class-absence'),
              controller: _absenceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mức vắng tối đa (%)',
              ),
              validator: validateAbsence,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('class-rssi'),
              controller: _rssiCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Ngưỡng tín hiệu RSSI (dBm)',
                helperText: 'Càng gần 0 càng yêu cầu ngồi gần giảng viên',
              ),
              validator: validateRssi,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tạo lớp'),
            ),
          ],
        ),
      ),
    );
  }
}
