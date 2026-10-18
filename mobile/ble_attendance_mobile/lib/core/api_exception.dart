import 'dart:io';

import 'package:dio/dio.dart';

/// Lỗi gọi API đã được chuẩn hóa: [code] để xử lý logic, [message] (tiếng Việt) để hiển thị.
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response != null) {
      final status = response.statusCode;
      final data = response.data;
      if (data is Map && data['detail'] is String) {
        final code = data['code'];
        return ApiException(
          code is String ? code : 'http_$status',
          data['detail'] as String,
          statusCode: status,
        );
      }
      if (status == 422) {
        return ApiException(
          'validation',
          'Dữ liệu chưa hợp lệ, hãy kiểm tra lại các ô nhập.',
          statusCode: status,
        );
      }
      return ApiException(
        'http_$status',
        'Máy chủ trả về lỗi ($status).',
        statusCode: status,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'timeout',
          'Máy chủ phản hồi quá chậm, hãy thử lại.',
        );
      case DioExceptionType.connectionError:
        return _network();
      default:
        if (error.error is SocketException) return _network();
        return ApiException('unknown', 'Đã xảy ra lỗi không mong muốn.');
    }
  }

  static ApiException _network() => ApiException(
    'network',
    'Không kết nối được máy chủ. Kiểm tra địa chỉ máy chủ và Wi-Fi.',
  );

  @override
  String toString() => message;
}

String friendlyError(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return ApiException.fromDio(error).message;
  return 'Đã xảy ra lỗi không mong muốn.';
}
