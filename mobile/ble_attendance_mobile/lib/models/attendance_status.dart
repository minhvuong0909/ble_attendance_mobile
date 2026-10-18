enum AttendanceStatus {
  present('Có mặt'),
  absent('Vắng'),
  excused('Có phép');

  const AttendanceStatus(this.label);

  final String label;

  static AttendanceStatus parse(String value) {
    for (final status in AttendanceStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Trạng thái điểm danh không hợp lệ: $value');
  }
}
