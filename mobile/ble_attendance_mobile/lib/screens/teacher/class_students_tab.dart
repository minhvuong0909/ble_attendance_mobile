import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/student_info.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/async_value_view.dart';

class ClassStudentsTab extends ConsumerWidget {
  const ClassStudentsTab({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(classStudentsProvider(classId));
    return AsyncValueView<List<StudentInfo>>(
      value: value,
      onRetry: () => ref.invalidate(classStudentsProvider(classId)),
      onRefresh: () => ref.refresh(classStudentsProvider(classId).future),
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'Chưa có sinh viên nào trong lớp',
      emptyIcon: Icons.groups_outlined,
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(classStudentsProvider(classId).future),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final s = items[index];
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('${s.studentId ?? '-'} · ${s.fullName}'),
            );
          },
        ),
      ),
    );
  }
}
