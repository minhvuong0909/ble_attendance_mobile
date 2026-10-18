import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../models/session_info.dart';
import '../../providers/repositories.dart';
import '../../providers/session_provider.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_chip.dart';

class ClassSessionsTab extends ConsumerStatefulWidget {
  const ClassSessionsTab({super.key, required this.classId});

  final String classId;

  @override
  ConsumerState<ClassSessionsTab> createState() => _ClassSessionsTabState();
}

class _ClassSessionsTabState extends ConsumerState<ClassSessionsTab> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(sessionRepositoryProvider).startSession(widget.classId);
      ref.invalidate(activeSessionProvider);
      ref.invalidate(classSessionsProvider(widget.classId));
      router.go('/teacher/live');
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(classSessionsProvider(widget.classId));
    return AsyncValueView<List<SessionInfo>>(
      value: value,
      onRetry: () => ref.invalidate(classSessionsProvider(widget.classId)),
      data: (sessions) {
        final running = sessions.any((s) => s.isActive);
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(classSessionsProvider(widget.classId).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: running || _busy ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu buổi học'),
              ),
              const SizedBox(height: 16),
              if (sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Lớp chưa có buổi học nào')),
                )
              else
                for (final s in sessions) _SessionTile(session: s),
            ],
          ),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final SessionInfo session;

  @override
  Widget build(BuildContext context) {
    final ends = session.endsAt;
    final String subtitle;
    if (session.isActive || ends == null) {
      subtitle = 'Chưa kết thúc';
    } else {
      final minutes = ends.difference(session.startsAt).inMinutes;
      subtitle = 'Đã kết thúc · ${minutes < 1 ? '< 1' : minutes} phút';
    }
    return Card(
      child: ListTile(
        title: Text(formatDateTime(session.startsAt)),
        subtitle: Text(subtitle),
        trailing: session.isActive
            ? const StatusChip(
                label: 'Đang diễn ra',
                color: Color(0xFF2E7D32),
                icon: Icons.sensors,
              )
            : null,
      ),
    );
  }
}
