import 'package:dio/dio.dart';

import '../core/api_exception.dart';
import '../core/app_constants.dart';
import '../core/validators.dart';
import 'token_store.dart';

/// Lớp duy nhất nói chuyện với backend: gắn token, chuẩn hóa lỗi, xử lý 401.
class ApiClient {
  ApiClient({required this.store, Dio? dio, String? defaultBaseUrl})
    : dio = dio ?? Dio(),
      _baseUrl = defaultBaseUrl ?? defaultApiBaseUrl {
    this.dio.options
      ..baseUrl = _baseUrl
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 12);
    this.dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachToken, onError: _handleUnauthorized),
    );
  }

  final TokenStore store;
  final Dio dio;
  String _baseUrl;

  /// Được gọi khi server trả 401 cho một phiên đã đăng nhập.
  void Function()? onUnauthorized;

  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final saved = await store.readBaseUrl();
    if (saved != null && saved.trim().isNotEmpty) {
      _baseUrl = normalizeBaseUrl(saved);
      dio.options.baseUrl = _baseUrl;
    }
  }

  Future<void> setBaseUrl(String input) async {
    final normalized = normalizeBaseUrl(input);
    await store.saveBaseUrl(normalized);
    _baseUrl = normalized;
    dio.options.baseUrl = normalized;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _send(() => dio.post<dynamic>(path, data: data));

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      return (await call()).data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await store.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _handleUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 401 && error.requestOptions.path != '/auth/login') {
      await store.clearToken();
      onUnauthorized?.call();
    }
    handler.next(error);
  }
}
