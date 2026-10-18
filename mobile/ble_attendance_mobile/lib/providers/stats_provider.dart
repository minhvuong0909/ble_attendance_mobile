import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_history.dart';
import '../models/class_stats.dart';
import 'repositories.dart';

final classStatsProvider = FutureProvider.autoDispose<List<ClassStats>>(
  (ref) => ref.watch(statsRepositoryProvider).stats(),
);

final classHistoryProvider = FutureProvider.autoDispose
    .family<List<AttendanceHistoryItem>, String>(
      (ref, classId) => ref.watch(statsRepositoryProvider).history(classId),
    );
