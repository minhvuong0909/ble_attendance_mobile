import '../models/class_report.dart';
import '../models/export_file.dart';
import 'api_client.dart';

abstract class ReportRepository {
  Future<ClassReport> classReport(String classId);
  Future<ExportFile> exportClass(String classId);
  Future<ExportFile> exportSession(String sessionId);
}

/// Lấy tên tệp từ header Content-Disposition, hoặc dùng [fallback] nếu thiếu.
String filenameFromDisposition(String? header, String fallback) {
  if (header == null) return fallback;
  final match = RegExp(r'filename="?([^";]+)"?').firstMatch(header);
  final name = match?.group(1)?.trim();
  return (name == null || name.isEmpty) ? fallback : name;
}

class ApiReportRepository implements ReportRepository {
  ApiReportRepository(this._api);

  final ApiClient _api;

  @override
  Future<ClassReport> classReport(String classId) async {
    final json = await _api.get('/classes/$classId/report');
    return ClassReport.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<ExportFile> exportClass(String classId) =>
      _export('/classes/$classId/report/export');

  @override
  Future<ExportFile> exportSession(String sessionId) =>
      _export('/sessions/$sessionId/export');

  Future<ExportFile> _export(String path) async {
    final result = await _api.download(path);
    return ExportFile(
      filename: filenameFromDisposition(
        result.contentDisposition,
        'attendance.xlsx',
      ),
      bytes: result.bytes,
    );
  }
}
