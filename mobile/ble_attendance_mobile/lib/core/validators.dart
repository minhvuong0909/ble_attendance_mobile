import 'dart:io';

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
  final hasScheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://').hasMatch(raw);
  if (!hasScheme &&
      RegExp(r'^(https?|ftp):', caseSensitive: false).hasMatch(raw)) {
    // Ví dụ "http:/x.com" gõ thiếu một dấu gạch chéo.
    throw ApiException('invalid_url', 'Địa chỉ máy chủ không hợp lệ.');
  }
  final Uri? uri;
  if (hasScheme) {
    uri = Uri.tryParse(raw);
  } else {
    // Địa chỉ trần: IP và localhost dùng http (mạng LAN), tên miền công khai dùng https.
    final probe = Uri.tryParse('http://$raw');
    final host = probe?.host ?? '';
    final local = host == 'localhost' || InternetAddress.tryParse(host) != null;
    uri = Uri.tryParse('${local ? 'http' : 'https'}://$raw');
  }
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw ApiException('invalid_url', 'Địa chỉ máy chủ không hợp lệ.');
  }
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  final port = uri.hasPort ? ':${uri.port}' : '';
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  return '${uri.scheme}://$host$port$path';
}
