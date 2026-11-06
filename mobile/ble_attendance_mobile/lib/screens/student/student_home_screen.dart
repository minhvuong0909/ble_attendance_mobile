import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../models/session_info.dart';
import '../../providers/repositories.dart';
import '../../providers/auth_controller.dart';
import '../../providers/session_provider.dart';
import '../../providers/student_beacon.dart';
import '../../widgets/ble_status_card.dart';
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

  void _syncBle(SessionInfo? session) {
    final id = ref.read(authControllerProvider).user?.studentId;
    if (id == null) return;
    ref.read(studentBeaconProvider.notifier).sync(session, id);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncBle(ref.read(activeSessionProvider).value);
    });
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
    ref.listen(activeSessionProvider, (_, next) {
      if (next.hasValue) _syncBle(next.value);
    });
    final ble = ref.watch(studentBeaconProvider);
    return AsyncValueView<SessionInfo?>(
      value: value,
      onRetry: () => ref.invalidate(activeSessionProvider),
      data: (session) => RefreshIndicator(
        onRefresh: () => ref.refresh(activeSessionProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _Greeting(name: ref.watch(authControllerProvider).user?.fullName),
            const SizedBox(height: 16),
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
                ble: StudentBleCard(
                  state: ble,
                  onRetry: () =>
                      ref.read(studentBeaconProvider.notifier).retry(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String? name;

  static String _salutation(int hour) {
    if (hour < 5 || hour >= 18) return 'Chào buổi tối';
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = (name ?? '').trim().split(' ').last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          first.isEmpty
              ? _salutation(DateTime.now().hour)
              : '${_salutation(DateTime.now().hour)}, $first',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Bạn chỉ cần mở ứng dụng trong giờ học, phần còn lại để chúng tôi lo.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.free_breakfast_outlined,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có buổi học nào đang diễn ra',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Khi giảng viên bắt đầu buổi học, thông tin sẽ hiện ở đây. Kéo xuống để làm mới.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    required this.ble,
  });

  final SessionInfo session;
  final bool busy;
  final bool done;
  final String? error;
  final VoidCallback onFinalize;
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
                    'Buổi học đang diễn ra',
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
