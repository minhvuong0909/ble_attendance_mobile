import '../core/formatters.dart';
import 'attendance_status.dart';

class ReportSession {
  const ReportSession({required this.id, required this.startsAt});

  factory ReportSession.fromJson(Map<String, dynamic> json) => ReportSession(
    id: json['id'] as String,
    startsAt: parseApiTime(json['starts_at'] as String),
  );

  final String id;
  final DateTime startsAt;
}

class ReportStudent {
  const ReportStudent({
    required this.studentUserId,
    required this.studentId,
    required this.studentName,
    required this.cells,
    required this.present,
    required this.absent,
    required this.excused,
    required this.attendancePercent,
    required this.absentPercent,
    required this.warning,
  });

  factory ReportStudent.fromJson(Map<String, dynamic> json) => ReportStudent(
    studentUserId: json['student_user_id'] as String,
    studentId: json['student_id'] as String?,
    studentName: json['student_name'] as String,
    cells: [
      for (final cell in json['cells'] as List<dynamic>)
        cell == null ? null : AttendanceStatus.parse(cell as String),
    ],
    present: json['present'] as int,
    absent: json['absent'] as int,
    excused: json['excused'] as int,
    attendancePercent: (json['attendance_percent'] as num).toDouble(),
    absentPercent: (json['absent_percent'] as num).toDouble(),
    warning: json['warning'] as bool,
  );

  final String studentUserId;
  final String? studentId;
  final String studentName;
  final List<AttendanceStatus?> cells;
  final int present;
  final int absent;
  final int excused;
  final double attendancePercent;
  final double absentPercent;
  final bool warning;
}

class ClassReport {
  const ClassReport({
    required this.classId,
    required this.courseCode,
    required this.courseName,
    required this.classCode,
    required this.semester,
    required this.sessions,
    required this.students,
    required this.averageAttendancePercent,
  });

  factory ClassReport.fromJson(Map<String, dynamic> json) => ClassReport(
    classId: json['class_id'] as String,
    courseCode: json['course_code'] as String,
    courseName: json['course_name'] as String,
    classCode: json['class_code'] as String,
    semester: json['semester'] as String,
    sessions: [
      for (final s in json['sessions'] as List<dynamic>)
        ReportSession.fromJson(s as Map<String, dynamic>),
    ],
    students: [
      for (final s in json['students'] as List<dynamic>)
        ReportStudent.fromJson(s as Map<String, dynamic>),
    ],
    averageAttendancePercent: (json['average_attendance_percent'] as num)
        .toDouble(),
  );

  final String classId;
  final String courseCode;
  final String courseName;
  final String classCode;
  final String semester;
  final List<ReportSession> sessions;
  final List<ReportStudent> students;
  final double averageAttendancePercent;

  String get title => '$courseCode · $classCode';
}
