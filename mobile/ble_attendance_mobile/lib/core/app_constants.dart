import 'package:flutter/foundation.dart' show kIsWeb;

const String teacherServiceUuid = '0000180D-0000-1000-8000-00805F9B34FB';
const String studentServiceUuid = '0000181C-0000-1000-8000-00805F9B34FB';

const int rssiThreshold = -88;
const int rssiWindowSize = 8;
const int manufacturerId = 0xFFFF; // dành cho thử nghiệm

const Duration teacherDetectionBatchInterval = Duration(seconds: 30);
const Duration teacherPollInterval = Duration(seconds: 10);
const Duration studentSessionPollInterval = Duration(seconds: 15);
const Duration proximityDebounceDuration = Duration(seconds: 3);

const String _envApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.7:8000',
);

/// Bản web được phục vụ từ chính backend nên dùng cùng origin.
String get defaultApiBaseUrl => kIsWeb ? Uri.base.origin : _envApiBaseUrl;
