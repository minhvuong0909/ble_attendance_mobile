enum ImportRowStatus {
  created,
  skipped,
  error;

  static ImportRowStatus parse(String value) {
    for (final status in ImportRowStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Trạng thái dòng import không hợp lệ: $value');
  }
}

class ImportRow {
  const ImportRow({
    required this.row,
    required this.status,
    required this.message,
  });

  factory ImportRow.fromJson(Map<String, dynamic> json) => ImportRow(
    row: json['row'] as int,
    status: ImportRowStatus.parse(json['status'] as String),
    message: json['message'] as String,
  );

  final int row;
  final ImportRowStatus status;
  final String message;
}

class ImportReport {
  const ImportReport({
    required this.kind,
    required this.dryRun,
    required this.committed,
    required this.total,
    required this.created,
    required this.skipped,
    required this.errors,
    required this.rows,
  });

  factory ImportReport.fromJson(Map<String, dynamic> json) => ImportReport(
    kind: json['kind'] as String,
    dryRun: json['dry_run'] as bool,
    committed: json['committed'] as bool,
    total: json['total'] as int,
    created: json['created'] as int,
    skipped: json['skipped'] as int,
    errors: json['errors'] as int,
    rows: [
      for (final r in json['rows'] as List<dynamic>)
        ImportRow.fromJson(r as Map<String, dynamic>),
    ],
  );

  final String kind;
  final bool dryRun;
  final bool committed;
  final int total;
  final int created;
  final int skipped;
  final int errors;
  final List<ImportRow> rows;

  /// Chỉ cho phép xác nhận khi không còn dòng lỗi và có ít nhất một dòng sẽ được tạo.
  bool get canCommit => errors == 0 && created > 0;
}
