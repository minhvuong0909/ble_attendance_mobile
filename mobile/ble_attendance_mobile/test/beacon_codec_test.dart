import 'dart:typed_data';

import 'package:ble_attendance_mobile/ble/beacon_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bucketOf floors epoch seconds to 30 second buckets', () {
    expect(bucketOf(DateTime.utc(1970, 1, 1, 0, 0, 29)), 0);
    expect(bucketOf(DateTime.utc(1970, 1, 1, 0, 0, 30)), 1);
    expect(bucketOf(DateTime.utc(2026, 10, 18, 3, 0, 0)), 59743080);
  });

  test('makeTag matches the backend HMAC vector', () {
    // python: hmac.new(b"secret", b"58691880", sha256).hexdigest()[:8]
    expect(makeTag('secret', 58691880), 'cfc89a9e');
  });

  test('teacher payload round-trips and rejects other shapes', () {
    final bytes = encodeTeacher('abcd1234');
    expect(bytes.first, 0x01);
    expect(decodeTeacher(bytes), 'abcd1234');
    expect(decodeTeacher(encodeStudent('25CE099', 'deadbeef')), isNull);
    expect(decodeTeacher(Uint8List.fromList([1, 65])), isNull);
    expect(decodeTeacher(Uint8List(0)), isNull);
  });

  test('student payload round-trips, uppercases the id and stays small', () {
    final bytes = encodeStudent('d26ce045', 'DEADBEEF');
    expect(bytes.first, 0x02);
    expect(bytes.length, lessThanOrEqualTo(21));
    final decoded = decodeStudent(bytes)!;
    expect(decoded.studentId, 'D26CE045');
    expect(decoded.tag, 'deadbeef');
    expect(decodeStudent(encodeTeacher('abcd1234')), isNull);
    expect(decodeStudent(Uint8List.fromList([2, 1, 2, 3])), isNull);
  });

  test('encoders reject invalid input', () {
    expect(() => encodeTeacher('short'), throwsArgumentError);
    expect(() => encodeStudent('X' * 17, 'deadbeef'), throwsArgumentError);
    expect(() => encodeStudent('25CE099', 'zzzzzzzz'), throwsArgumentError);
  });
}
