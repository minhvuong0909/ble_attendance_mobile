import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/class_info.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/async_value_view.dart';

class TeacherClassesScreen extends ConsumerWidget {
  const TeacherClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myClassListProvider);
    return AsyncValueView<List<ClassInfo>>(
      value: value,
      onRetry: () => ref.invalidate(myClassListProvider),
      onRefresh: () => ref.refresh(myClassListProvider.future),
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Bạn chưa được phân công lớp nào',
      emptyIcon: Icons.class_outlined,
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(myClassListProvider.future),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _ClassCard(info: items[index]),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.info});

  final ClassInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/teacher/classes/${info.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: _details(theme)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(info.courseName, style: theme.textTheme.titleMedium),
        Text('${info.title} · ${info.semester}'),
        const SizedBox(height: 4),
        Text(
          '${info.studentCount} sinh viên',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
