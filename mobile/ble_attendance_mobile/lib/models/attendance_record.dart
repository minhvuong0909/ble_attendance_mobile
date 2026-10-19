import '../core/formatters.dart';
import 'attendance_status.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.studentUserId,
    required this.studentId,
    required this.studentName,
    required this.detectionCount,
    required this.presenceRatio,
    required this.status,
    required this.finalized,
    required this.firstSeenAt,
    required this.overridden,
    required this.overrideReason,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        studentUserId: json['student_user_id'] as String,
        studentId: json['student_id'] as String?,
        studentName: json['student_name'] as String,
        detectionCount: json['detection_count'] as int,
        presenceRatio: (json['presence_ratio'] as num).toDouble(),
        status: AttendanceStatus.parse(json['status'] as String),
        finalized: json['finalized'] as bool,
        firstSeenAt: json['first_seen_at'] == null
            ? null
            : parseApiTime(json['first_seen_at'] as String),
        overridden: json['overridden'] as bool,
        overrideReason: json['override_reason'] as String?,
      );

  final String studentUserId;
  final String? studentId;
  final String studentName;
  final int detectionCount;
  final double presenceRatio;
  final AttendanceStatus status;
  final bool finalized;
  final DateTime? firstSeenAt;
  final bool overridden;
  final String? overrideReason;
}

class SessionAttendance {
  const SessionAttendance({
    required this.sessionId,
    required this.classId,
    required this.totalStudents,
    required this.presentStudents,
    required this.records,
  });

  factory SessionAttendance.fromJson(Map<String, dynamic> json) =>
      SessionAttendance(
        sessionId: json['session_id'] as String,
        classId: json['class_id'] as String,
        totalStudents: json['total_students'] as int,
        presentStudents: json['present_students'] as int,
        records: [
          for (final item in json['records'] as List<dynamic>)
            AttendanceRecord.fromJson(item as Map<String, dynamic>),
        ],
      );

  final String sessionId;
  final String classId;
  final int totalStudents;
  final int presentStudents;
  final List<AttendanceRecord> records;
}
