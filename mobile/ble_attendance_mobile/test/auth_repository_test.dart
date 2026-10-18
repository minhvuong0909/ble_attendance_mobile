import 'dart:convert';

import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:ble_attendance_mobile/data/auth_repository.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/memory_token_store.dart';

const _userJson = {
  'id': 'u1',
  'full_name': 'Nguyen Van A',
  'role': 'student',
  'student_id': '25CE099',
  'teacher_id': null,
  'must_change_password': false,
};

void main() {
  late FakeAdapter adapter;
  late ApiAuthRepository repo;

  setUp(() {
    adapter = FakeAdapter((options) async {
      switch (options.path) {
        case '/auth/login':
          return jsonBody({'access_token': 'jwt', 'token_type': 'bearer', 'must_change_password': true});
        case '/auth/me':
        case '/auth/register':
          return jsonBody(_userJson);
        default:
          return jsonBody({'message': 'ok'});
      }
    });
    final client = ApiClient(
      store: MemoryTokenStore(),
      dio: Dio()..httpClientAdapter = adapter,
      defaultBaseUrl: 'http://x',
    );
    repo = ApiAuthRepository(client);
  });

  test('login posts credentials and parses the result', () async {
    final result = await repo.login('T001', 'Pass@123');
    expect(result.accessToken, 'jwt');
    expect(result.mustChangePassword, isTrue);
    final request = adapter.requests.single;
    expect(request.path, '/auth/login');
    expect(jsonDecode(jsonEncode(request.data)), {'identifier': 'T001', 'password': 'Pass@123'});
  });

  test('register posts the student payload without a role', () async {
    final user = await repo.register(fullName: 'Nguyen Van A', identifier: '25CE099', password: 'Pass@123');
    expect(user.role, AppRole.student);
    expect(
      jsonDecode(jsonEncode(adapter.requests.single.data)),
      {'full_name': 'Nguyen Van A', 'identifier': '25CE099', 'password': 'Pass@123'},
    );
  });

  test('me and changePassword use the expected endpoints', () async {
    expect((await repo.me()).loginId, '25CE099');
    await repo.changePassword(oldPassword: 'a', newPassword: 'bbbbbb');
    expect(adapter.requests.map((r) => r.path), ['/auth/me', '/auth/change-password']);
    expect(
      jsonDecode(jsonEncode(adapter.requests.last.data)),
      {'old_password': 'a', 'new_password': 'bbbbbb'},
    );
  });
}
