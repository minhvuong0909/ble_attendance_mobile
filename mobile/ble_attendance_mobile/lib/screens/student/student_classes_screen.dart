import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/class_stats.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_chip.dart';

class StudentClassesScreen extends ConsumerWidget {
  const StudentClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(classStatsProvider);
    return AsyncValueView<List<ClassStats>>(
      value: value,
      onRetry: () => ref.invalidate(classStatsProvider),
      onRefresh: () => ref.refresh(classStatsProvider.future),
      isEmpty: (items) => items.isEmpty,
      emptyMessage:
          'Bạn chưa được xếp lớp nào.\nLiên hệ admin hoặc giáo vụ để được xếp lớp.',
      emptyIcon: Icons.school_outlined,
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(classStatsProvider.future),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _ClassCard(stats: items[index]),
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
