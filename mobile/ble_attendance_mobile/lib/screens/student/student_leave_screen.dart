import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../models/leave_request.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_chip.dart';

class StudentLeaveScreen extends ConsumerWidget {
  const StudentLeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myLeaveProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final sent = await context.push<bool>('/student/leave/new');
          if (sent == true) ref.invalidate(myLeaveProvider);
        },
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Xin phép'),
      ),
      body: AsyncValueView<List<LeaveRequest>>(
        value: value,
        onRetry: () => ref.invalidate(myLeaveProvider),
        onRefresh: () => ref.refresh(myLeaveProvider.future),
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Bạn chưa gửi đơn xin phép nào',
        emptyIcon: Icons.event_busy_outlined,
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(myLeaveProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _LeaveCard(leave: items[index]),
          ),
        ),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave});

  final LeaveRequest leave;

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
                    leave.classTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                leaveChip(leave.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Ngày xin phép: ${formatDate(leave.date)}'),
            const SizedBox(height: 4),
            Text(leave.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (leave.reviewNote != null && leave.reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Phản hồi: ${leave.reviewNote}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
