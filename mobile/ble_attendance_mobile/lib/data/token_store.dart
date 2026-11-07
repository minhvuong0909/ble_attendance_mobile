import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nơi lưu token đăng nhập và địa chỉ máy chủ trên thiết bị.
abstract class TokenStore {
  Future<String?> readToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
  Future<String?> readBaseUrl();
  Future<void> saveBaseUrl(String url);

  /// Mã thiết bị: sinh một lần, giữ nguyên qua các lần đăng xuất.
  Future<String?> readDeviceId();
  Future<void> saveDeviceId(String id);
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'token';
  static const _baseUrlKey = 'api_base_url';
  static const _deviceIdKey = 'device_id';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);
  @override
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  @override
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
  @override
  Future<String?> readBaseUrl() => _storage.read(key: _baseUrlKey);
  @override
  Future<void> saveBaseUrl(String url) =>
      _storage.write(key: _baseUrlKey, value: url);
  @override
  Future<String?> readDeviceId() => _storage.read(key: _deviceIdKey);
  @override
  Future<void> saveDeviceId(String id) =>
      _storage.write(key: _deviceIdKey, value: id);
}

/// Bản web: lưu bằng localStorage. flutter_secure_storage cần ngữ cảnh HTTPS,
/// trong khi bản web chạy qua HTTP trong mạng LAN.
class PrefsTokenStore implements TokenStore {
  static const _tokenKey = 'token';
  static const _baseUrlKey = 'api_base_url';
  static const _deviceIdKey = 'device_id';

  @override
  Future<String?> readToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);
  @override
  Future<void> saveToken(String token) async {
    await (await SharedPreferences.getInstance()).setString(_tokenKey, token);
  }

  @override
  Future<void> clearToken() async {
    await (await SharedPreferences.getInstance()).remove(_tokenKey);
  }

  @override
  Future<String?> readBaseUrl() async =>
      (await SharedPreferences.getInstance()).getString(_baseUrlKey);
  @override
  Future<void> saveBaseUrl(String url) async {
    await (await SharedPreferences.getInstance()).setString(_baseUrlKey, url);
  }

  @override
  Future<String?> readDeviceId() async =>
      (await SharedPreferences.getInstance()).getString(_deviceIdKey);
  @override
  Future<void> saveDeviceId(String id) async {
    await (await SharedPreferences.getInstance()).setString(_deviceIdKey, id);
  }
}

TokenStore createTokenStore() =>
    kIsWeb ? PrefsTokenStore() : SecureTokenStore();
