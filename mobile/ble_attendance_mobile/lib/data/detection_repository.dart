import 'api_client.dart';

/// Một lần máy giảng viên bắt được gói của sinh viên.
class DetectionEntry {
  const DetectionEntry({
    required this.sessionId,
    required this.studentId,
    required this.bucket,
    required this.tag,
    required this.rssi,
    required this.observedAt,
  });

  final String sessionId;
  final String studentId;
  final int bucket;
  final String tag;
  final int rssi;
  final DateTime observedAt;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'student_identifier': studentId,
    'bucket': bucket,
    'tag': tag,
    'rssi': rssi,
    'observed_at': observedAt.toUtc().toIso8601String(),
  };
}

class BatchResult {
  const BatchResult({required this.recorded, required this.rejected});
  final int recorded;
  final int rejected;
}

abstract class DetectionRepository {
  Future<BatchResult> postBatch(List<DetectionEntry> entries);
}

class ApiDetectionRepository implements DetectionRepository {
  ApiDetectionRepository(this._api);

  final ApiClient _api;

  @override
  Future<BatchResult> postBatch(List<DetectionEntry> entries) async {
    final json =
        await _api.post(
              '/detections/batch',
              data: {'detections': entries.map((e) => e.toJson()).toList()},
            )
            as Map<String, dynamic>;
    return BatchResult(
      recorded: json['recorded'] as int,
      rejected: json['rejected'] as int,
    );
  }
}
