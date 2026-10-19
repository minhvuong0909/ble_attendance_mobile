import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../models/attendance_record.dart';
import '../../models/session_info.dart';
import '../../providers/repositories.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/warning_banner.dart';
import 'override_dialog.dart';

/// Danh sách điểm danh của một buổi (đang diễn ra hoặc đã kết thúc) và chỉnh tay từng sinh viên.
/// Trả về các widget xếp dọc, dùng bên trong một ListView/Column của màn hình cha.
class SessionAttendanceView extends ConsumerWidget {
  const SessionAttendanceView({super.key, required this.session});

  final SessionInfo session;

  Future<void> _override(
    BuildContext context,
    WidgetRef ref,
    AttendanceRecord record,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => OverrideDialog(
        record: record,
        onSubmit: (status, reason) => ref
            .read(attendanceRepositoryProvider)
            .overrideStatus(
              sessionId: session.id,
              studentUserId: record.studentUserId,
              status: status,
              reason: reason,
            ),
      ),
    );
    if (saved == true) {
      ref.invalidate(sessionAttendanceProvider(session.id));
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã cập nhật điểm danh')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(sessionAttendanceProvider(session.id));
    if (value.hasValue) {
      final data = value.value!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (value.hasError) ...[
            const WarningBanner(
              'Không cập nhật được, đang hiển thị dữ liệu gần nhất.',
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Có mặt ${data.presentStudents} / ${data.totalStudents} sinh viên',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (data.records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Lớp chưa có sinh viên nào')),
            )
          else
            for (final r in data.records)
              _RecordTile(
                session: session,
                record: r,
                onTap: () => _override(context, ref, r),
              ),
        ],
      );
    }
    if (value.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        Text(friendlyError(value.error ?? '')),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () =>
              ref.invalidate(sessionAttendanceProvider(session.id)),
          child: const Text('Thử lại'),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.session,
    required this.record,
    required this.onTap,
  });

  final SessionInfo session;
  final AttendanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final late = lateMinutes(session.startsAt, record.firstSeenAt) ?? 0;
    final parts = <String>[
      'Hiện diện ${(record.presenceRatio * 100).round()}%',
      '${record.detectionCount} lần phát hiện',
      if (record.finalized) 'Đã chốt',
      if (late > 0) 'Trễ $late phút',
    ];
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('${record.studentId ?? '-'} · ${record.studentName}'),
        subtitle: Text(
          [
            parts.join(' · '),
            if (record.overridden)
              'Đã chỉnh tay: ${record.overrideReason ?? ''}',
          ].join('\n'),
        ),
        isThreeLine: record.overridden,
        trailing: attendanceChip(record.status),
      ),
    );
  }
}
