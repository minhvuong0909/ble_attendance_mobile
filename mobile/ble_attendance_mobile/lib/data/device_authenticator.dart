import 'package:local_auth/local_auth.dart';

import '../core/api_exception.dart';

/// Xác thực người dùng bằng vân tay/khuôn mặt hoặc khóa màn hình của thiết bị.
abstract class DeviceAuthenticator {
  /// Trả true nếu xác thực thành công, false nếu người dùng hủy.
  Future<bool> authenticate(String reason);
}

class LocalAuthAuthenticator implements DeviceAuthenticator {
  LocalAuthAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> authenticate(String reason) async {
    if (!await _auth.isDeviceSupported()) {
      throw ApiException(
        'device_auth_unavailable',
        'Thiết bị chưa cài khóa màn hình hoặc sinh trắc học. Hãy cài đặt rồi thử lại.',
      );
    }
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } on LocalAuthException catch (error) {
      switch (error.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
          return false;
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noBiometricHardware:
          throw ApiException(
            'device_auth_unavailable',
            'Thiết bị chưa cài khóa màn hình hoặc sinh trắc học. Hãy cài đặt rồi thử lại.',
          );
        default:
          throw ApiException(
            'device_auth_failed',
            'Không xác thực được, hãy thử lại.',
          );
      }
    }
  }
}
