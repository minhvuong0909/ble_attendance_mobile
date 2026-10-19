import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../models/leave_request.dart';
import '../../providers/repositories.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_chip.dart';

class TeacherLeaveScreen extends ConsumerStatefulWidget {
  const TeacherLeaveScreen({super.key});

  @override
  ConsumerState<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends ConsumerState<TeacherLeaveScreen> {
  bool _pendingOnly = true;
  bool _busy = false;

  Future<void> _review(LeaveRequest leave, String decision) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<({String? note})>(
      context: context,
      builder: (_) => _ReviewDialog(approve: decision == 'approved'),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(leaveRepositoryProvider)
          .review(leaveId: leave.id, decision: decision, note: result.note);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approved' ? 'Đã duyệt đơn' : 'Đã từ chối đơn',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      ref.invalidate(teacherLeaveProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(teacherLeaveProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Chờ duyệt')),
              ButtonSegment(value: false, label: Text('Tất cả')),
            ],
            selected: {_pendingOnly},
            onSelectionChanged: (s) => setState(() => _pendingOnly = s.first),
          ),
        ),
        Expanded(
          child: AsyncValueView<List<LeaveRequest>>(
            value: value,
            onRetry: () => ref.invalidate(teacherLeaveProvider),
            onRefresh: () => ref.refresh(teacherLeaveProvider.future),
            isEmpty: (items) => _visible(items).isEmpty,
            emptyMessage: _pendingOnly
                ? 'Không có đơn nào chờ duyệt'
                : 'Chưa có đơn xin phép nào',
            emptyIcon: Icons.event_available_outlined,
            data: (items) {
              final visible = _visible(items);
              return RefreshIndicator(
                onRefresh: () => ref.refresh(teacherLeaveProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _LeaveCard(
                    leave: visible[index],
                    busy: _busy,
                    onApprove: () => _review(visible[index], 'approved'),
                    onReject: () => _review(visible[index], 'rejected'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<LeaveRequest> _visible(List<LeaveRequest> items) => _pendingOnly
      ? items.where((l) => l.status == LeaveStatus.pending).toList()
      : items;
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({
    required this.leave,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final LeaveRequest leave;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${leave.studentName} · ${leave.studentId ?? '-'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                leaveChip(leave.status),
              ],
            ),
            Text(leave.classTitle),
            Text('Ngày xin phép: ${formatDate(leave.date)}'),
            const SizedBox(height: 4),
            Text(leave.reason),
            if (leave.reviewNote != null && leave.reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Phản hồi: ${leave.reviewNote}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (leave.status == LeaveStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onApprove,
                      child: const Text('Duyệt'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onReject,
                      child: const Text('Từ chối'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.approve});

  final bool approve;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.approve ? 'Duyệt đơn xin phép' : 'Từ chối đơn xin phép',
      ),
      content: TextField(
        key: const Key('review-note'),
        controller: _noteCtrl,
        maxLength: 255,
        decoration: const InputDecoration(
          labelText: 'Ghi chú cho sinh viên (không bắt buộc)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final note = _noteCtrl.text.trim();
            Navigator.of(context).pop((note: note.isEmpty ? null : note));
          },
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
