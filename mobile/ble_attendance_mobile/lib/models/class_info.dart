class ClassInfo {
  const ClassInfo({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.classCode,
    required this.semester,
    required this.teacherUserId,
    required this.teacherName,
    required this.joinCode,
    required this.maxAbsencePercent,
    required this.rssiThreshold,
    required this.studentCount,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) => ClassInfo(
    id: json['id'] as String,
    courseId: json['course_id'] as String,
    courseCode: json['course_code'] as String,
    courseName: json['course_name'] as String,
    classCode: json['class_code'] as String,
    semester: json['semester'] as String,
    teacherUserId: json['teacher_user_id'] as String?,
    teacherName: json['teacher_name'] as String?,
    joinCode: json['join_code'] as String?,
    maxAbsencePercent: json['max_absence_percent'] as int,
    rssiThreshold: json['rssi_threshold'] as int,
    studentCount: json['student_count'] as int,
  );

  final String id;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String classCode;
  final String semester;
  final String? teacherUserId;
  final String? teacherName;
  final String? joinCode;
  final int maxAbsencePercent;
  final int rssiThreshold;
  final int studentCount;

  String get title => '$courseCode · $classCode';
}
