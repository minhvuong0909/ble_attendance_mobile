import 'app_role.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.studentId,
    required this.teacherId,
    required this.mustChangePassword,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    role: AppRole.parse(json['role'] as String),
    studentId: json['student_id'] as String?,
    teacherId: json['teacher_id'] as String?,
    mustChangePassword: (json['must_change_password'] as bool?) ?? false,
  );

  final String id;
  final String fullName;
  final AppRole role;
  final String? studentId;
  final String? teacherId;
  final bool mustChangePassword;

  /// Mã dùng để đăng nhập (mã SV, hoặc mã GV/admin).
  String get loginId => studentId ?? teacherId ?? '';
}
