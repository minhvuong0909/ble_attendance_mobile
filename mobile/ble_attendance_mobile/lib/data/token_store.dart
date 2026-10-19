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
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'token';
  static const _baseUrlKey = 'api_base_url';
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
}

/// Bản web: lưu bằng localStorage. flutter_secure_storage cần ngữ cảnh HTTPS,
/// trong khi bản web chạy qua HTTP trong mạng LAN.
class PrefsTokenStore implements TokenStore {
  static const _tokenKey = 'token';
  static const _baseUrlKey = 'api_base_url';

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
}

TokenStore createTokenStore() =>
    kIsWeb ? PrefsTokenStore() : SecureTokenStore();
