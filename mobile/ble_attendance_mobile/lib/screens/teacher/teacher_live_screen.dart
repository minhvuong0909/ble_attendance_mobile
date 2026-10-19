import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../models/session_info.dart';
import '../../providers/repositories.dart';
import '../../providers/session_provider.dart';
import '../../providers/teacher_beacon.dart';
import '../../widgets/ble_status_card.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/export_button.dart';
import '../../widgets/status_chip.dart';
import 'session_attendance_view.dart';

const _pollInterval = Duration(seconds: 10);

class TeacherLiveScreen extends ConsumerStatefulWidget {
  const TeacherLiveScreen({super.key});

  @override
  ConsumerState<TeacherLiveScreen> createState() => _TeacherLiveScreenState();
}

class _TeacherLiveScreenState extends ConsumerState<TeacherLiveScreen> {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(teacherBeaconProvider.notifier)
            .sync(ref.read(activeSessionProvider).value);
      }
    });
    _timer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    final session = ref.read(activeSessionProvider).value;
    ref.invalidate(activeSessionProvider);
    if (session != null) {
      ref.invalidate(sessionAttendanceProvider(session.id));
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFinalization(SessionInfo session) => _run(() async {
    await ref.read(sessionRepositoryProvider).openFinalization(session.id);
    ref.invalidate(activeSessionProvider);
  }, success: 'Đã mở chốt điểm danh');

  Future<void> _end(SessionInfo session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc buổi học?'),
        content: Text(
          session.finalizationOpen
              ? 'Hệ thống sẽ chốt kết quả điểm danh cả lớp. Không thể hoàn tác.'
              : 'Bạn chưa mở chốt điểm danh nên sinh viên chưa xác nhận được: '
                    'mọi sinh viên không có đơn xin phép sẽ bị tính vắng. '
                    'Hãy mở chốt trước khi kết thúc, hoặc chỉnh tay kết quả sau đó.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await ref.read(sessionRepositoryProvider).endSession(session.id);
      ref.invalidate(activeSessionProvider);
      ref.invalidate(classSessionsProvider(session.classId));
    }, success: 'Đã kết thúc buổi học');
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(activeSessionProvider);
    ref.listen(activeSessionProvider, (_, next) {
      if (next.hasValue) {
        ref.read(teacherBeaconProvider.notifier).sync(next.value);
      }
    });
    final ble = ref.watch(teacherBeaconProvider);
    return AsyncValueView<SessionInfo?>(
      value: value,
      onRetry: () => ref.invalidate(activeSessionProvider),
      data: (session) => RefreshIndicator(
        onRefresh: () async {
          _refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (session == null)
              const _NoSession()
            else ...[
              _SessionCard(
                session: session,
                busy: _busy,
                onOpen: () => _openFinalization(session),
                onEnd: () => _end(session),
                ble: TeacherBleCard(
                  state: ble,
                  onRetry: () =>
                      ref.read(teacherBeaconProvider.notifier).retry(),
                ),
              ),
              const SizedBox(height: 12),
              ExportButton(
                label: 'Xuất Excel buổi này',
                onExport: () => ref
                    .read(reportRepositoryProvider)
                    .exportSession(session.id),
              ),
              const SizedBox(height: 16),
              SessionAttendanceView(session: session),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.sensors_off, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Bạn chưa bắt đầu buổi học nào',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Vào tab Lớp học, chọn lớp rồi bấm "Bắt đầu buổi học".',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.onOpen,
    required this.onEnd,
    required this.ble,
  });

  final SessionInfo session;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onEnd;
  final Widget ble;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đang diễn ra',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(session.courseName, style: theme.textTheme.titleLarge),
            Text('${session.courseCode} · ${session.classCode}'),
            Text('Bắt đầu lúc ${formatDateTime(session.startsAt)}'),
            const SizedBox(height: 12),
            ble,
            const SizedBox(height: 12),
            if (session.finalizationOpen)
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: 'Đã mở chốt',
                  color: Color(0xFF2E7D32),
                  icon: Icons.lock_open,
                ),
              )
            else
              FilledButton.icon(
                onPressed: busy ? null : onOpen,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Mở chốt điểm danh'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onEnd,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Kết thúc buổi'),
            ),
          ],
        ),
      ),
    );
  }
}
