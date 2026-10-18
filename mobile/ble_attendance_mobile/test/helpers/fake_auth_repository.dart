import 'package:ble_attendance_mobile/data/auth_repository.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/auth_user.dart';

AuthUser testUser({
  AppRole role = AppRole.student,
  bool mustChangePassword = false,
  String name = 'Nguyen Van A',
}) => AuthUser(
  id: 'u1',
  fullName: name,
  role: role,
  studentId: role == AppRole.student ? '25CE099' : null,
  teacherId: role == AppRole.student ? null : 'T001',
  mustChangePassword: mustChangePassword,
);

/// Repository giả: mỗi hành vi là một hàm có thể thay trong test.
class FakeAuthRepository implements AuthRepository {
  Future<LoginResult> Function(String id, String password) onLogin =
      (id, password) async => LoginResult(accessToken: 'token-$id', mustChangePassword: false);
  Future<AuthUser> Function() onMe = () async => testUser();
  Future<AuthUser> Function(String fullName, String identifier, String password) onRegister =
      (name, id, password) async => testUser(name: name);
  Future<void> Function(String oldPassword, String newPassword) onChangePassword =
      (oldPassword, newPassword) async {};

  final List<String> loginIds = [];

  @override
  Future<LoginResult> login(String id, String password) {
    loginIds.add(id);
    return onLogin(id, password);
  }

  @override
  Future<AuthUser> me() => onMe();

  @override
  Future<AuthUser> register({
    required String fullName,
    required String identifier,
    required String password,
  }) => onRegister(fullName, identifier, password);

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) =>
      onChangePassword(oldPassword, newPassword);
}
