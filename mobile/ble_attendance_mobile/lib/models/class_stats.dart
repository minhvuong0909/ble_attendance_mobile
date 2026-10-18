class ClassStats {
  const ClassStats({
    required this.classId,
    required this.courseCode,
    required this.courseName,
    required this.classCode,
    required this.semester,
    required this.totalSessions,
    required this.present,
    required this.absent,
    required this.excused,
    required this.attendancePercent,
    required this.absentPercent,
    required this.maxAbsencePercent,
    required this.warning,
  });

  factory ClassStats.fromJson(Map<String, dynamic> json) => ClassStats(
    classId: json['class_id'] as String,
    courseCode: json['course_code'] as String,
    courseName: json['course_name'] as String,
    classCode: json['class_code'] as String,
    semester: json['semester'] as String,
    totalSessions: json['total_sessions'] as int,
    present: json['present'] as int,
    absent: json['absent'] as int,
    excused: json['excused'] as int,
    attendancePercent: (json['attendance_percent'] as num).toDouble(),
    absentPercent: (json['absent_percent'] as num).toDouble(),
    maxAbsencePercent: json['max_absence_percent'] as int,
    warning: json['warning'] as bool,
  );

  final String classId;
  final String courseCode;
  final String courseName;
  final String classCode;
  final String semester;
  final int totalSessions;
  final int present;
  final int absent;
  final int excused;
  final double attendancePercent;
  final double absentPercent;
  final int maxAbsencePercent;
  final bool warning;

  String get title => '$courseCode · $classCode';
}
