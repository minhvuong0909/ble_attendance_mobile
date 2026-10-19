import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../models/class_stats.dart';
import '../../providers/repositories.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/status_chip.dart';

class StudentClassesScreen extends ConsumerWidget {
  const StudentClassesScreen({super.key});

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final joinedTitle = await showDialog<String>(
      context: context,
      builder: (_) => _JoinDialog(
        onJoin: (code) async =>
            (await ref.read(classRepositoryProvider).join(code)).title,
      ),
    );
    if (joinedTitle == null) return;
    ref.invalidate(classStatsProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('Đã tham gia lớp $joinedTitle')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(classStatsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _join(context, ref),
        icon: const Icon(Icons.group_add),
        label: const Text('Tham gia lớp'),
      ),
      body: AsyncValueView<List<ClassStats>>(
        value: value,
        onRetry: () => ref.invalidate(classStatsProvider),
        onRefresh: () => ref.refresh(classStatsProvider.future),
        isEmpty: (items) => items.isEmpty,
        emptyMessage:
            'Bạn chưa tham gia lớp nào.\nBấm "Tham gia lớp" và nhập mã lớp từ giảng viên.',
        emptyIcon: Icons.school_outlined,
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(classStatsProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ClassCard(stats: items[index]),
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.stats});

  final ClassStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = stats.warning
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/student/classes/${stats.classId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: (stats.attendancePercent / 100).clamp(0, 1),
                        strokeWidth: 5,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: FittedBox(
                        child: Text(
                          '${stats.attendancePercent.round()}%',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stats.courseName, style: theme.textTheme.titleMedium),
                    Text('${stats.title} · ${stats.semester}'),
                    Text(
                      '${stats.totalSessions} buổi đã học',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (stats.warning) ...[
                      const SizedBox(height: 4),
                      const StatusChip(
                        label: 'Vượt mức vắng cho phép',
                        color: Color(0xFFC62828),
                        icon: Icons.warning_amber,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog({required this.onJoin});

  final Future<String> Function(String code) onJoin;

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final title = await widget.onJoin(_codeCtrl.text.trim().toUpperCase());
      if (mounted) Navigator.of(context).pop(title);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhập mã lớp'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('join-code'),
              controller: _codeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Mã lớp',
                helperText: 'Do giảng viên cung cấp',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập mã lớp'
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Tham gia'),
        ),
      ],
    );
  }
}
