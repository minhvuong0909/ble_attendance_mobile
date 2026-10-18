import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/attendance_history.dart';
import '../../models/class_stats.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/warning_banner.dart';

class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref
        .watch(classStatsProvider)
        .value
        ?.where((s) => s.classId == classId)
        .firstOrNull;
    final history = ref.watch(classHistoryProvider(classId));
    return Scaffold(
      appBar: AppBar(title: Text(stats?.title ?? 'Chi tiết lớp')),
      body: AsyncValueView<List<AttendanceHistoryItem>>(
        value: history,
        onRetry: () => ref.invalidate(classHistoryProvider(classId)),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(classStatsProvider);
            ref.invalidate(classHistoryProvider(classId));
            await ref.read(classHistoryProvider(classId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (stats != null) _Summary(stats: stats),
              const SizedBox(height: 16),
              Text(
                'Lịch sử điểm danh',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Chưa có buổi học nào kết thúc')),
                )
              else
                for (final item in items) _HistoryTile(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final ClassStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stats.courseName, style: theme.textTheme.titleLarge),
            Text('${stats.title} · ${stats.semester}'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stats.attendancePercent.round()}%',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('chuyên cần'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                Text('Có mặt: ${stats.present}'),
                Text('Vắng: ${stats.absent}'),
                Text('Có phép: ${stats.excused}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Mức vắng tối đa cho phép: ${stats.maxAbsencePercent}%',
              style: theme.textTheme.bodySmall,
            ),
            if (stats.warning) ...[
              const SizedBox(height: 12),
              WarningBanner(
                'Vượt mức vắng cho phép: bạn đã vắng ${stats.absentPercent.round()}% '
                'số buổi (tối đa ${stats.maxAbsencePercent}%).',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final AttendanceHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final late = item.lateMinutes ?? 0;
    final detail =
        'Hiện diện ${(item.presenceRatio * 100).round()}%${late > 0 ? ' · Trễ $late phút' : ''}';
    return Card(
      child: ListTile(
        title: Text(formatDateTime(item.startsAt)),
        subtitle: Text(detail),
        trailing: attendanceChip(item.status),
      ),
    );
  }
}
