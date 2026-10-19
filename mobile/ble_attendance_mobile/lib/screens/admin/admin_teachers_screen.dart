import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/auth_user.dart';
import '../../providers/admin_providers.dart';
import '../../providers/repositories.dart';
import '../../widgets/async_value_view.dart';
import 'import_entry_button.dart';
import '../../widgets/error_banner.dart';
import 'temp_password_notice.dart';

class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  ConsumerState<AdminTeachersScreen> createState() =>
      _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends ConsumerState<AdminTeachersScreen> {
  bool _busy = false;

  Future<void> _add() async {
    final created = await showDialog<AuthUser>(
      context: context,
      builder: (_) => _TeacherDialog(
        onCreate: (id, name) => ref
            .read(adminRepositoryProvider)
            .createTeacher(teacherId: id, fullName: name),
      ),
    );
    if (created == null || !mounted) return;
    ref.invalidate(adminTeachersProvider);
    await showTempPasswordNotice(
      context,
      title: 'Đã tạo tài khoản',
      loginId: created.loginId,
      name: created.fullName,
    );
  }

  Future<void> _reset(AuthUser teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt lại mật khẩu?'),
        content: Text(
          'Mật khẩu của ${teacher.fullName} sẽ trở về mã đăng nhập và họ phải đổi khi đăng nhập.',
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
      await ref.read(adminRepositoryProvider).resetPassword(teacher.id);
      if (!mounted) return;
      await showTempPasswordNotice(
        context,
        title: 'Đã đặt lại mật khẩu',
        loginId: teacher.loginId,
        name: teacher.fullName,
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminTeachersProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _add,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm giảng viên'),
      ),
      body: Column(
        children: [
          const ImportEntryButton(
            label: 'Nhập từ file',
            path: '/admin/import/teachers',
          ),
          Expanded(
            child: AsyncValueView<List<AuthUser>>(
              value: value,
              onRetry: () => ref.invalidate(adminTeachersProvider),
              onRefresh: () => ref.refresh(adminTeachersProvider.future),
              isEmpty: (items) => items.isEmpty,
              emptyMessage: 'Chưa có giảng viên nào',
              emptyIcon: Icons.badge_outlined,
              data: (items) => RefreshIndicator(
                onRefresh: () => ref.refresh(adminTeachersProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final t = items[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(t.fullName),
                        subtitle: Text(t.loginId),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Tùy chọn',
                          onSelected: (_) => _reset(t),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'reset',
                              child: Text('Đặt lại mật khẩu'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherDialog extends StatefulWidget {
  const _TeacherDialog({required this.onCreate});

  final Future<AuthUser> Function(String id, String name) onCreate;

  @override
  State<_TeacherDialog> createState() => _TeacherDialogState();
}

class _TeacherDialogState extends State<_TeacherDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await widget.onCreate(
        _idCtrl.text.trim().toUpperCase(),
        _nameCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(created);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Thêm giảng viên'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('teacher-id'),
                  controller: _idCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã giảng viên',
                    helperText: 'Ví dụ T002',
                  ),
                  validator: (v) {
                    final length = (v ?? '').trim().length;
                    return length < 3 || length > 16
                        ? 'Mã giảng viên từ 3 đến 16 ký tự'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('teacher-name'),
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  validator: (v) {
                    final length = (v ?? '').trim().length;
                    return length < 2 || length > 120
                        ? 'Họ tên từ 2 đến 120 ký tự'
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
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}
