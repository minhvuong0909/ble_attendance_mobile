import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_report.dart';
import '../models/session_info.dart';
import '../models/student_info.dart';
import 'repositories.dart';

final classStudentsProvider = FutureProvider.autoDispose
    .family<List<StudentInfo>, String>(
      (ref, classId) =>
          ref.watch(classRepositoryProvider).classStudents(classId),
    );

final classSessionsProvider = FutureProvider.autoDispose
    .family<List<SessionInfo>, String>(
      (ref, classId) =>
          ref.watch(sessionRepositoryProvider).classSessions(classId),
    );

final classReportProvider = FutureProvider.autoDispose
    .family<ClassReport, String>(
      (ref, classId) =>
          ref.watch(reportRepositoryProvider).classReport(classId),
    );
