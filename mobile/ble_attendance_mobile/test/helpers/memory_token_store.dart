import 'package:ble_attendance_mobile/data/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore({this.token, this.baseUrl, this.deviceId});

  String? token;
  String? baseUrl;
  String? deviceId;

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
  @override
  Future<String?> readDeviceId() async => deviceId;
  @override
  Future<void> saveDeviceId(String value) async => deviceId = value;
}
