import 'package:ble_attendance_mobile/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatDateTime and formatDate use dd/MM/yyyy', () {
    final value = DateTime(2026, 10, 5, 9, 7);
    expect(formatDateTime(value), '05/10/2026 09:07');
    expect(formatDate(value), '05/10/2026');
  });

  test('toApiDate uses yyyy-MM-dd', () {
    expect(toApiDate(DateTime(2026, 3, 9, 23, 59)), '2026-03-09');
  });

  test('parseApiTime keeps the instant of a UTC timestamp', () {
    final parsed = parseApiTime('2026-10-18T03:00:00Z');
    expect(parsed.isAtSameMomentAs(DateTime.utc(2026, 10, 18, 3)), isTrue);
  });
}
