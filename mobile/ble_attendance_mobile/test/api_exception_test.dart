import 'dart:io';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _error({
  DioExceptionType type = DioExceptionType.badResponse,
  int? status,
  Object? data,
  Object? error,
}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    error: error,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  _codeTypes();
  test('maps backend {detail, code} to ApiException', () {
    final e = ApiException.fromDio(
      _error(
        status: 409,
        data: {'detail': 'Mã đã tồn tại', 'code': 'student_exists'},
      ),
    );
    expect(e.code, 'student_exists');
    expect(e.message, 'Mã đã tồn tại');
    expect(e.statusCode, 409);
  });

  test('maps FastAPI default 422 list to validation', () {
    final e = ApiException.fromDio(
      _error(
        status: 422,
        data: {
          'detail': [
            {'msg': 'bad'},
          ],
        },
      ),
    );
    expect(e.code, 'validation');
    expect(e.message, contains('hợp lệ'));
  });

  test('maps unknown HTTP error to http_<status>', () {
    final e = ApiException.fromDio(_error(status: 500, data: 'oops'));
    expect(e.code, 'http_500');
    expect(e.statusCode, 500);
  });

  test('maps connection problems to network and timeout', () {
    expect(
      ApiException.fromDio(_error(type: DioExceptionType.connectionError)).code,
      'network',
    );
    expect(
      ApiException.fromDio(
        _error(type: DioExceptionType.connectionTimeout),
      ).code,
      'timeout',
    );
    expect(
      ApiException.fromDio(_error(type: DioExceptionType.receiveTimeout)).code,
      'timeout',
    );
    expect(
      ApiException.fromDio(
        _error(
          type: DioExceptionType.unknown,
          error: const SocketException('x'),
        ),
      ).code,
      'network',
    );
    expect(
      ApiException.fromDio(_error(type: DioExceptionType.unknown)).code,
      'unknown',
    );
  });

  test('network and timeout messages are Vietnamese', () {
    final network = ApiException.fromDio(
      _error(type: DioExceptionType.connectionError),
    );
    expect(network.message, contains('máy chủ'));
  });

  test('friendlyError handles ApiException, DioException and others', () {
    expect(friendlyError(ApiException('x', 'Lỗi A')), 'Lỗi A');
    expect(
      friendlyError(
        _error(status: 409, data: {'detail': 'Lỗi B', 'code': 'b'}),
      ),
      'Lỗi B',
    );
    expect(friendlyError(StateError('boom')), contains('không mong muốn'));
  });
}

void _codeTypes() {
  test('a non-string code in the error body falls back to http_<status>', () {
    final e = ApiException.fromDio(
      _error(status: 409, data: {'detail': 'Lỗi', 'code': 5}),
    );
    expect(e.code, 'http_409');
    expect(e.message, 'Lỗi');
  });
}
