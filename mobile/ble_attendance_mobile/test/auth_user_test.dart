import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppRole.parse reads the three roles and rejects others', () {
    expect(AppRole.parse('admin'), AppRole.admin);
    expect(AppRole.parse('teacher'), AppRole.teacher);
    expect(AppRole.parse('student'), AppRole.student);
    expect(() => AppRole.parse('root'), throwsFormatException);
  });

  test('AppRole.homePath', () {
    expect(AppRole.admin.homePath, '/admin');
    expect(AppRole.teacher.homePath, '/teacher');
    expect(AppRole.student.homePath, '/student');
  });

  test('AuthUser.fromJson for a student', () {
    final user = AuthUser.fromJson({
      'id': 'u1',
      'full_name': 'Nguyen Van A',
      'role': 'student',
      'student_id': '25CE099',
      'teacher_id': null,
      'must_change_password': false,
    });
    expect(user.role, AppRole.student);
    expect(user.loginId, '25CE099');
    expect(user.mustChangePassword, isFalse);
  });

  test('AuthUser.fromJson for teacher and admin uses teacher_id as login id', () {
    for (final role in ['teacher', 'admin']) {
      final user = AuthUser.fromJson({
        'id': 'u2',
        'full_name': 'Co Lan',
        'role': role,
        'student_id': null,
        'teacher_id': 'T001',
        'must_change_password': true,
      });
      expect(user.loginId, 'T001');
      expect(user.mustChangePassword, isTrue);
    }
  });
}
