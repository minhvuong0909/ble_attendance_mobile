import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../models/session_info.dart';
import '../../providers/repositories.dart';
import '../../providers/session_provider.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/warning_banner.dart';

const _refreshInterval = Duration(seconds: 15);

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  Timer? _timer;
  bool _busy = false;
  String? _doneSessionId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      _refreshInterval,
      (_) => ref.invalidate(activeSessionProvider),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _finalize(SessionInfo session) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(deviceAuthenticatorProvider)
          .authenticate('Xác nhận điểm danh');
      if (!ok) return; // Người dùng hủy: không phải lỗi.
      await ref.read(sessionRepositoryProvider).finalize(session.id);
      if (mounted) setState(() => _doneSessionId = session.id);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(activeSessionProvider);
    return AsyncValueView<SessionInfo?>(
      value: value,
      onRetry: () => ref.invalidate(activeSessionProvider),
      data: (session) => RefreshIndicator(
        onRefresh: () => ref.refresh(activeSessionProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (value.hasError) ...[
              const WarningBanner(
                'Không cập nhật được, đang hiển thị dữ liệu gần nhất.',
              ),
              const SizedBox(height: 12),
            ],
            if (session == null)
              const _NoSession()
            else
              _SessionCard(
                session: session,
                busy: _busy,
                done: _doneSessionId == session.id,
                error: _error,
                onFinalize: () => _finalize(session),
              ),
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
          Icon(Icons.event_busy, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Hiện không có buổi học nào đang diễn ra',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('Kéo xuống để làm mới', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.done,
    required this.error,
    required this.onFinalize,
  });

  final SessionInfo session;
  final bool busy;
  final bool done;
  final String? error;
  final VoidCallback onFinalize;

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
            const SizedBox(height: 16),
            if (done)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã xác nhận điểm danh',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                session.finalizationOpen
                    ? 'Giảng viên đã mở chốt. Hãy xác nhận khi bạn đang ở trong lớp.'
                    : 'Giảng viên chưa mở chốt điểm danh',
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(error!),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: session.finalizationOpen && !busy
                    ? onFinalize
                    : null,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint),
                label: const Text('Xác nhận điểm danh'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
