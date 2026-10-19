import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/class_info.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/async_value_view.dart';

class AdminClassesScreen extends ConsumerWidget {
  const AdminClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminClassesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final created = await context.push<bool>('/admin/classes/new');
          if (created == true) ref.invalidate(adminClassesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo lớp'),
      ),
      body: AsyncValueView<List<ClassInfo>>(
        value: value,
        onRetry: () => ref.invalidate(adminClassesProvider),
        onRefresh: () => ref.refresh(adminClassesProvider.future),
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Chưa có lớp nào',
        emptyIcon: Icons.class_outlined,
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(adminClassesProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _ClassCard(info: items[index]),
          ),
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
        onTap: () => context.push('/admin/classes/${info.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.courseName, style: theme.textTheme.titleMedium),
              Text('${info.title} · ${info.semester}'),
              const SizedBox(height: 4),
              Text(
                info.teacherName == null
                    ? 'Chưa phân công giảng viên'
                    : 'GV: ${info.teacherName}',
                style: info.teacherName == null
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      )
                    : null,
              ),
              Text(
                '${info.studentCount} sinh viên',
                style: theme.textTheme.bodySmall,
              ),
              if (info.joinCode != null)
                Text(
                  'Mã lớp: ${info.joinCode}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
