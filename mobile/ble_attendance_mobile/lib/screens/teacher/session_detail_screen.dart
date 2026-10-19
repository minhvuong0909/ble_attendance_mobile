import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/session_info.dart';
import '../../providers/repositories.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/export_button.dart';
import 'session_attendance_view.dart';

/// Kết quả điểm danh của một buổi đã kết thúc: xem, chỉnh tay và xuất Excel.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.session});

  final SessionInfo session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(formatDateTime(session.startsAt))),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(sessionAttendanceProvider(session.id).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              session.courseName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${session.courseCode} · ${session.classCode}'),
            const SizedBox(height: 12),
            ExportButton(
              label: 'Xuất Excel buổi này',
              onExport: () =>
                  ref.read(reportRepositoryProvider).exportSession(session.id),
            ),
            const SizedBox(height: 16),
            SessionAttendanceView(session: session),
          ],
        ),
      ),
    );
  }
}
