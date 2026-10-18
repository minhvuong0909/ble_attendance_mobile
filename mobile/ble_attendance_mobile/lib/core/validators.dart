import 'api_exception.dart';

class Validators {
  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập $label';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }
    return null;
  }

  static String? confirm(String? value, String other) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu';
    if (value != other) return 'Mật khẩu nhập lại không khớp';
    return null;
  }
}

String normalizeId(String value) => value.trim().toUpperCase();

String normalizeBaseUrl(String input) {
  final raw = input.trim();
  if (raw.isEmpty) {
    throw ApiException('invalid_url', 'Vui lòng nhập địa chỉ máy chủ.');
  }
  final withScheme = raw.startsWith('http://') || raw.startsWith('https://')
      ? raw
      : 'http://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    throw ApiException('invalid_url', 'Địa chỉ máy chủ không hợp lệ.');
  }
  return withScheme.endsWith('/')
      ? withScheme.substring(0, withScheme.length - 1)
      : withScheme;
}
