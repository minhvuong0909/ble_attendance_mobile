import '../core/formatters.dart';

class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.classId,
    required this.classCode,
    required this.courseCode,
    required this.courseName,
    required this.teacherUserId,
    required this.beaconCode,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    required this.finalizationOpen,
    required this.beaconSecret,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
    id: json['id'] as String,
    classId: json['class_id'] as String,
    classCode: json['class_code'] as String,
    courseCode: json['course_code'] as String,
    courseName: json['course_name'] as String,
    teacherUserId: json['teacher_user_id'] as String,
    beaconCode: json['beacon_code'] as String,
    startsAt: parseApiTime(json['starts_at'] as String),
    endsAt: json['ends_at'] == null
        ? null
        : parseApiTime(json['ends_at'] as String),
    isActive: json['is_active'] as bool,
    finalizationOpen: json['finalization_open'] as bool,
    beaconSecret: json['beacon_secret'] as String?,
  );

  final String id;
  final String classId;
  final String classCode;
  final String courseCode;
  final String courseName;
  final String teacherUserId;
  final String beaconCode;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final bool finalizationOpen;
  final String? beaconSecret;
}
