import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/class_info.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/search_field.dart';
import 'import_entry_button.dart';

class AdminClassesScreen extends ConsumerStatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  ConsumerState<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends ConsumerState<AdminClassesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          const ImportEntryButton(
            label: 'Nhập môn/lớp từ file',
            path: '/admin/import/classes',
          ),
          SearchField(
            hint: 'Tìm theo môn, lớp, giảng viên, mã lớp',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: AsyncValueView<List<ClassInfo>>(
              value: value,
              onRetry: () => ref.invalidate(adminClassesProvider),
              onRefresh: () => ref.refresh(adminClassesProvider.future),
              isEmpty: (items) => items.isEmpty,
              emptyMessage: 'Chưa có lớp nào',
              emptyIcon: Icons.class_outlined,
              data: (all) {
                final items = all
                    .where(
                      (c) => matchesQuery(_query, [
                        c.courseName,
                        c.title,
                        c.semester,
                        c.teacherName,
                        c.joinCode,
                      ]),
                    )
                    .toList();
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(adminClassesProvider.future),
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(48),
                              child: Center(
                                child: Text('Không có lớp nào khớp từ khóa'),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 0),
                          itemBuilder: (context, index) =>
                              _ClassCard(info: items[index]),
                        ),
                );
              },
            ),
          ),
        ],
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    avatar: const Icon(Icons.groups_outlined, size: 16),
                    label: Text('${info.studentCount} sinh viên'),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (info.joinCode != null)
                    Chip(
                      avatar: const Icon(Icons.vpn_key_outlined, size: 16),
                      label: Text('Mã lớp ${info.joinCode}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
