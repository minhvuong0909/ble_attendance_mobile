import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../models/attendance_status.dart';
import '../../models/class_report.dart';
import '../../providers/repositories.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/export_button.dart';

final _dayMonth = DateFormat('dd/MM');

class ClassReportTab extends ConsumerWidget {
  const ClassReportTab({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(classReportProvider(classId));
    return AsyncValueView<ClassReport>(
      value: value,
      onRetry: () => ref.invalidate(classReportProvider(classId)),
      onRefresh: () => ref.refresh(classReportProvider(classId).future),
      isEmpty: (r) => r.students.isEmpty,
      emptyMessage: 'Chưa có sinh viên trong lớp',
      emptyIcon: Icons.groups_outlined,
      data: (report) {
        if (report.sessions.isEmpty) {
          return const Center(child: Text('Lớp chưa có buổi học nào kết thúc'));
        }
        return Column(
          children: [
            _Header(report: report, classId: classId),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(classReportProvider(classId).future),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _Table(report: report),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.report, required this.classId});

  final ClassReport report;
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trung bình lớp: ${formatPercent(report.averageAttendancePercent)}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${report.students.length} sinh viên · ${report.sessions.length} buổi',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ExportButton(
            onExport: () =>
                ref.read(reportRepositoryProvider).exportClass(classId),
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.report});

  final ClassReport report;

  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFC62828);
  static const _orange = Color(0xFFEF6C00);

  Widget _cell(AttendanceStatus? status) {
    switch (status) {
      case AttendanceStatus.present:
        return const Text(
          'P',
          style: TextStyle(color: _green, fontWeight: FontWeight.bold),
        );
      case AttendanceStatus.absent:
        return const Text(
          'A',
          style: TextStyle(color: _red, fontWeight: FontWeight.bold),
        );
      case AttendanceStatus.excused:
        return const Text(
          'E',
          style: TextStyle(color: _orange, fontWeight: FontWeight.bold),
        );
      case null:
        return const Text('–');
    }
  }

  @override
  Widget build(BuildContext context) {
    final warningColor = Theme.of(
      context,
    ).colorScheme.errorContainer.withValues(alpha: 0.5);
    return DataTable(
      columnSpacing: 20,
      columns: [
        const DataColumn(label: Text('MSSV')),
        const DataColumn(label: Text('Họ tên')),
        for (final s in report.sessions)
          DataColumn(label: Text(_dayMonth.format(s.startsAt))),
        const DataColumn(label: Text('Có mặt'), numeric: true),
        const DataColumn(label: Text('Vắng'), numeric: true),
        const DataColumn(label: Text('Có phép'), numeric: true),
        const DataColumn(label: Text('%'), numeric: true),
      ],
      rows: [
        for (final s in report.students)
          DataRow(
            color: s.warning ? WidgetStatePropertyAll(warningColor) : null,
            cells: [
              DataCell(Text(s.studentId ?? '-')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.warning)
                      const Tooltip(
                        message: 'Vượt mức vắng cho phép',
                        child: Icon(
                          Icons.warning_amber,
                          size: 18,
                          color: _orange,
                        ),
                      ),
                    if (s.warning) const SizedBox(width: 4),
                    Text(s.studentName),
                  ],
                ),
              ),
              for (final cell in s.cells) DataCell(_cell(cell)),
              DataCell(Text('${s.present}')),
              DataCell(Text('${s.absent}')),
              DataCell(Text('${s.excused}')),
              DataCell(Text(formatPercent(s.attendancePercent))),
            ],
          ),
      ],
    );
  }
}
