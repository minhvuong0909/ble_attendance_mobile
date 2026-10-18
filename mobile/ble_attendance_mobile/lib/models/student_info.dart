class StudentInfo {
  const StudentInfo({
    required this.id,
    required this.studentId,
    required this.fullName,
  });

  factory StudentInfo.fromJson(Map<String, dynamic> json) => StudentInfo(
    id: json['id'] as String,
    studentId: json['student_id'] as String?,
    fullName: json['full_name'] as String,
  );

  final String id;
  final String? studentId;
  final String fullName;
}
