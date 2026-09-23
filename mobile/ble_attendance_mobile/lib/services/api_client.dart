import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/app_constants.dart';
import '../models/app_role.dart';

class ApiClient {
  ApiClient();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _baseUrl = defaultApiBaseUrl;

  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final saved = await _storage.read(key: 'api_base_url');
    if (saved != null && saved.trim().isNotEmpty) {
      final normalized = _normalizeBaseUrl(saved);
      _baseUrl = normalized;
      _dio.options.baseUrl = normalized;
    }
  }

  Future<void> setBaseUrl(String input) async {
    final normalized = _normalizeBaseUrl(input);
    _baseUrl = normalized;
    _dio.options.baseUrl = normalized;
    await _storage.write(key: 'api_base_url', value: normalized);
  }

  Future<void> healthCheck() async {
    await _dio.get('/health');
  }

  // Lưu thông tin phiên đăng nhập trên thiết bị.
  Future<void> saveToken(String token) =>
      _storage.write(key: 'token', value: token);
  Future<String?> readToken() => _storage.read(key: 'token');
  Future<void> saveRole(String role) =>
      _storage.write(key: 'role', value: role);
  Future<String?> readRole() => _storage.read(key: 'role');
  Future<void> saveIdentifier(String id) =>
      _storage.write(key: 'identifier', value: id);
  Future<String?> readIdentifier() => _storage.read(key: 'identifier');

  Future<void> clearSession() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'role');
    await _storage.delete(key: 'identifier');
  }

  Future<void> enablePersistentConnection() async {
    _dio.options.connectTimeout = const Duration(seconds: 12);
    _dio.options.receiveTimeout = const Duration(seconds: 12);
  }

  Future<String?> _token() => _storage.read(key: 'token');

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _dio.get(
      path,
      options: Options(headers: {'Authorization': 'Bearer ${await _token()}'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post(
      path,
      data: data,
      options: Options(headers: {'Authorization': 'Bearer ${await _token()}'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> register({
    required String fullName,
    required String identifier,
    required String password,
    required AppRole role,
  }) async {
    await _dio.post(
      '/auth/register',
      data: {
        'full_name': fullName,
        'role': role.name,
        'identifier': identifier,
        'password': password,
      },
    );
  }

  Future<String> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'identifier': identifier, 'password': password},
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return json['access_token'] as String;
  }

  Future<Map<String, dynamic>> startSession(String subject) =>
      _post('/sessions', {'subject': subject});

  Future<Map<String, dynamic>> endSession(String sessionId) =>
      _post('/sessions/$sessionId/end', {});

  Future<Map<String, dynamic>> getActiveSession() => _get('/sessions/active');

  Future<Map<String, dynamic>> openFinalization(String sessionId) =>
      _post('/teacher/sessions/$sessionId/open-finalization', {});

  Future<Map<String, dynamic>> submitDetectionBatch(
    List<Map<String, dynamic>> detections,
  ) => _post('/detections/batch', {'detections': detections});

  Future<Map<String, dynamic>> finalizeAttendance(String sessionId) => _post(
    '/attendance/finalize',
    {'session_id': sessionId, 'biometric_verified': true},
  );

  Future<Map<String, dynamic>> getAttendanceSummary(String sessionId) =>
      _get('/teacher/sessions/$sessionId/attendance-summary');

  Future<List<int>> downloadAttendanceExcel(String sessionId) async {
    final response = await _dio.get(
      '/teacher/sessions/$sessionId/attendance-export',
      options: Options(
        headers: {'Authorization': 'Bearer ${await _token()}'},
        responseType: ResponseType.bytes,
      ),
    );
    return response.data as List<int>;
  }

  String _normalizeBaseUrl(String input) {
    final raw = input.trim();
    if (raw.isEmpty) throw Exception('Server URL is required.');
    final withScheme = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'http://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('Enter a valid server URL.');
    }
    return withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;
  }
}
