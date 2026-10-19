import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/class_info.dart';
import '../../models/student_info.dart';
import '../../providers/admin_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/async_value_view.dart';
import 'import_entry_button.dart';
import 'temp_password_notice.dart';

/// Lớp mà admin đang xem ở tab Sinh viên (giữ lại khi chuyển tab).
class SelectedClassNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final adminSelectedClassProvider =
    NotifierProvider<SelectedClassNotifier, String?>(SelectedClassNotifier.new);

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() =>
      _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  bool _busy = false;

  Future<void> _reset(StudentInfo student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt lại mật khẩu?'),
        content: Text(
          'Mật khẩu của ${student.fullName} sẽ trở về mã sinh viên và họ phải đổi khi đăng nhập.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRepositoryProvider).resetPassword(student.id);
      if (!mounted) return;
      await showTempPasswordNotice(
        context,
        title: 'Đã đặt lại mật khẩu',
        loginId: student.studentId ?? '',
        name: student.fullName,
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(adminClassesProvider);
    final selected = ref.watch(adminSelectedClassProvider);
    return AsyncValueView<List<ClassInfo>>(
      value: classes,
      onRetry: () => ref.invalidate(adminClassesProvider),
      onRefresh: () => ref.refresh(adminClassesProvider.future),
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Chưa có lớp nào',
      emptyIcon: Icons.class_outlined,
      data: (items) {
        final current = items.any((c) => c.id == selected) ? selected : null;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                key: const Key('students-class'),
                isExpanded: true,
                initialValue: current,
                decoration: const InputDecoration(labelText: 'Lớp'),
                items: [
                  for (final c in items)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(c.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) =>
                    ref.read(adminSelectedClassProvider.notifier).select(v),
              ),
            ),
            if (current != null)
              ImportEntryButton(
                label: 'Nhập danh sách sinh viên',
                path: '/admin/import/students?classId=$current',
              ),
            Expanded(
              child: current == null
                  ? const Center(child: Text('Chọn một lớp để xem sinh viên'))
                  : _StudentList(
                      classId: current,
                      onReset: _reset,
                      busy: _busy,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StudentList extends ConsumerWidget {
  const _StudentList({
    required this.classId,
    required this.onReset,
    required this.busy,
  });

  final String classId;
  final void Function(StudentInfo student) onReset;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(classStudentsProvider(classId));
    return AsyncValueView<List<StudentInfo>>(
      value: value,
      onRetry: () => ref.invalidate(classStudentsProvider(classId)),
      onRefresh: () => ref.refresh(classStudentsProvider(classId).future),
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Lớp chưa có sinh viên',
      emptyIcon: Icons.groups_outlined,
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(classStudentsProvider(classId).future),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final s = items[index];
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('${s.studentId ?? '-'} · ${s.fullName}'),
              trailing: PopupMenuButton<String>(
                tooltip: 'Tùy chọn',
                enabled: !busy,
                onSelected: (_) => onReset(s),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'reset',
                    child: Text('Đặt lại mật khẩu'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
