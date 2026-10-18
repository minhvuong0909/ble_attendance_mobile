import 'package:ble_attendance_mobile/data/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore({this.token, this.baseUrl});

  String? token;
  String? baseUrl;

  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> saveToken(String value) async => token = value;
  @override
  Future<void> clearToken() async => token = null;
  @override
  Future<String?> readBaseUrl() async => baseUrl;
  @override
  Future<void> saveBaseUrl(String value) async => baseUrl = value;
}
