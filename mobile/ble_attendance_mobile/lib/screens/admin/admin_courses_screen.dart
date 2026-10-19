import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course.dart';
import '../../providers/admin_providers.dart';
import '../../providers/repositories.dart';
import '../../widgets/async_value_view.dart';
import 'course_form_dialog.dart';

class AdminCoursesScreen extends ConsumerWidget {
  const AdminCoursesScreen({super.key});

  Future<void> _openDialog(
    BuildContext context,
    WidgetRef ref, {
    Course? course,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(adminRepositoryProvider);
    final result = await showDialog<CourseDialogResult>(
      context: context,
      builder: (_) => CourseFormDialog(
        course: course,
        onSave: (code, name, credits) async {
          if (course == null) {
            await repo.createCourse(code: code, name: name, credits: credits);
          } else {
            await repo.updateCourse(
              course.id,
              name: name == course.name ? null : name,
              credits: credits == course.credits ? null : credits,
            );
          }
        },
        onDelete: course == null ? null : () => repo.deleteCourse(course.id),
      ),
    );
    if (result == null) return;
    ref.invalidate(adminCoursesProvider);
    final message = switch (result) {
      CourseDialogResult.deleted => 'Đã xóa môn học',
      CourseDialogResult.saved =>
        course == null ? 'Đã thêm môn học' : 'Đã cập nhật môn học',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminCoursesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _openDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm môn'),
      ),
      body: AsyncValueView<List<Course>>(
        value: value,
        onRetry: () => ref.invalidate(adminCoursesProvider),
        onRefresh: () => ref.refresh(adminCoursesProvider.future),
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'Chưa có môn học nào',
        emptyIcon: Icons.menu_book_outlined,
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(adminCoursesProvider.future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = items[index];
              return Card(
                child: ListTile(
                  title: Text('${c.code} · ${c.name}'),
                  subtitle: c.credits == null
                      ? null
                      : Text('${c.credits} tín chỉ'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _openDialog(context, ref, course: c),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
