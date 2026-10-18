import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_info.dart';
import 'repositories.dart';

/// Buổi học đang diễn ra của người dùng (null nếu không có).
final activeSessionProvider = FutureProvider.autoDispose<SessionInfo?>(
  (ref) => ref.watch(sessionRepositoryProvider).activeSession(),
);
