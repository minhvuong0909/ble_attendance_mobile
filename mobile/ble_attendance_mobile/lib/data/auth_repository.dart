import '../models/auth_user.dart';
import 'api_client.dart';

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.mustChangePassword,
  });

  final String accessToken;
  final bool mustChangePassword;
}

abstract class AuthRepository {
  Future<LoginResult> login(String id, String password);
  Future<AuthUser> register({
    required String fullName,
    required String identifier,
    required String password,
  });
  Future<AuthUser> me();
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<LoginResult> login(String id, String password) async {
    final json =
        await _api.post(
              '/auth/login',
              data: {'identifier': id, 'password': password},
            )
            as Map<String, dynamic>;
    return LoginResult(
      accessToken: json['access_token'] as String,
      mustChangePassword: (json['must_change_password'] as bool?) ?? false,
    );
  }

  @override
  Future<AuthUser> register({
    required String fullName,
    required String identifier,
    required String password,
  }) async {
    final json =
        await _api.post(
              '/auth/register',
              data: {
                'full_name': fullName,
                'identifier': identifier,
                'password': password,
              },
            )
            as Map<String, dynamic>;
    return AuthUser.fromJson(json);
  }

  @override
  Future<AuthUser> me() async =>
      AuthUser.fromJson(await _api.get('/auth/me') as Map<String, dynamic>);

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/change-password',
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }
}
