import '../core/formatters.dart';

enum LeaveStatus {
  pending('Chờ duyệt'),
  approved('Đã duyệt'),
  rejected('Bị từ chối');

  const LeaveStatus(this.label);

  final String label;

  static LeaveStatus parse(String value) {
    for (final status in LeaveStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Trạng thái đơn không hợp lệ: $value');
  }
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.studentUserId,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.courseCode,
    required this.classCode,
    required this.date,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.reviewedAt,
    required this.reviewNote,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    id: json['id'] as int,
    studentUserId: json['student_user_id'] as String,
    studentId: json['student_id'] as String?,
    studentName: json['student_name'] as String,
    classId: json['class_id'] as String,
    courseCode: json['course_code'] as String,
    classCode: json['class_code'] as String,
    date: DateTime.parse(json['date'] as String),
    reason: json['reason'] as String,
    status: LeaveStatus.parse(json['status'] as String),
    createdAt: parseApiTime(json['created_at'] as String),
    reviewedAt: json['reviewed_at'] == null
        ? null
        : parseApiTime(json['reviewed_at'] as String),
    reviewNote: json['review_note'] as String?,
  );

  final int id;
  final String studentUserId;
  final String? studentId;
  final String studentName;
  final String classId;
  final String courseCode;
  final String classCode;
  final DateTime date;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  String get classTitle => '$courseCode · $classCode';
}
