import '../core/formatters.dart';
import 'attendance_status.dart';

class AttendanceHistoryItem {
  const AttendanceHistoryItem({
    required this.sessionId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.presenceRatio,
    required this.firstSeenAt,
    required this.lateMinutes,
  });

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) =>
      AttendanceHistoryItem(
        sessionId: json['session_id'] as String,
        startsAt: parseApiTime(json['starts_at'] as String),
        endsAt: json['ends_at'] == null
            ? null
            : parseApiTime(json['ends_at'] as String),
        status: AttendanceStatus.parse(json['status'] as String),
        presenceRatio: (json['presence_ratio'] as num).toDouble(),
        firstSeenAt: json['first_seen_at'] == null
            ? null
            : parseApiTime(json['first_seen_at'] as String),
        lateMinutes: json['late_minutes'] as int?,
      );

  final String sessionId;
  final DateTime startsAt;
  final DateTime? endsAt;
  final AttendanceStatus status;
  final double presenceRatio;
  final DateTime? firstSeenAt;
  final int? lateMinutes;
}
