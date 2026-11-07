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
          return RefreshIndicator(
            onRefresh: () => ref.refresh(classReportProvider(classId).future),
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: constraints.maxHeight,
                    child: const Center(
                      child: Text('Lớp chưa có buổi học nào kết thúc'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(classReportProvider(classId).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(report: report, classId: classId),
                _Table(report: report),
              ],
            ),
          ),
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Column(
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

  static const _rowHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final warningColor = Theme.of(
      context,
    ).colorScheme.errorContainer.withValues(alpha: 0.5);
    WidgetStateProperty<Color?>? rowColor(ReportStudent s) =>
        s.warning ? WidgetStatePropertyAll(warningColor) : null;

    // Cột sinh viên đứng yên, các ngày và tổng cuộn ngang bên cạnh nó.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DataTable(
          headingRowHeight: _rowHeight,
          dataRowMinHeight: _rowHeight,
          dataRowMaxHeight: _rowHeight,
          horizontalMargin: 16,
          columns: const [DataColumn(label: Text('Sinh viên'))],
          rows: [
            for (final s in report.students)
              DataRow(
                color: rowColor(s),
                cells: [DataCell(_StudentCell(student: s))],
              ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            child: DataTable(
              headingRowHeight: _rowHeight,
              dataRowMinHeight: _rowHeight,
              dataRowMaxHeight: _rowHeight,
              columnSpacing: 20,
              columns: [
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
                    color: rowColor(s),
                    cells: [
                      for (final cell in s.cells) DataCell(_cell(cell)),
                      DataCell(Text('${s.present}')),
                      DataCell(Text('${s.absent}')),
                      DataCell(Text('${s.excused}')),
                      DataCell(Text(formatPercent(s.attendancePercent))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentCell extends StatelessWidget {
  const _StudentCell({required this.student});

  final ReportStudent student;

  static const _orange = Color(0xFFEF6C00);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (student.warning)
                const Tooltip(
                  message: 'Vượt mức vắng cho phép',
                  child: Icon(Icons.warning_amber, size: 18, color: _orange),
                ),
              if (student.warning) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  student.studentName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(student.studentId ?? '-', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
