import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
