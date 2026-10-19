import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_record.dart';
import '../models/class_report.dart';
import '../models/leave_request.dart';
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

final sessionAttendanceProvider = FutureProvider.autoDispose
    .family<SessionAttendance, String>(
      (ref, sessionId) =>
          ref.watch(attendanceRepositoryProvider).sessionAttendance(sessionId),
    );

/// Đơn xin phép của mọi lớp mà giảng viên phụ trách, mới nhất trước.
final teacherLeaveProvider = FutureProvider.autoDispose<List<LeaveRequest>>((
  ref,
) async {
  final classes = await ref.watch(classRepositoryProvider).myClasses();
  final leaveRepo = ref.watch(leaveRepositoryProvider);
  final lists = await Future.wait([
    for (final c in classes) leaveRepo.classRequests(c.id),
  ]);
  final all = [for (final list in lists) ...list]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all;
});
