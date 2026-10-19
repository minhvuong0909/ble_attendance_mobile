import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Mã hóa gói quảng cáo BLE và tag HMAC (khớp backend/app/services/beacon.py).
const int teacherPacketType = 0x01;
const int studentPacketType = 0x02;
const int bucketSeconds = 30;
const int beaconCodeLength = 8;
const int tagLength = 8;
const int maxStudentIdLength = 16;

int bucketOf(DateTime moment) =>
    moment.toUtc().millisecondsSinceEpoch ~/ 1000 ~/ bucketSeconds;

String makeTag(String secret, int bucket) {
  final digest = Hmac(
    sha256,
    utf8.encode(secret),
  ).convert(utf8.encode('$bucket'));
  return digest.toString().substring(0, tagLength);
}

final _hex = RegExp(r'^[0-9a-fA-F]+$');
final _idChars = RegExp(r'^[A-Za-z0-9]+$');

Uint8List encodeTeacher(String beaconCode) {
  if (beaconCode.length != beaconCodeLength || !_idChars.hasMatch(beaconCode)) {
    throw ArgumentError('Mã buổi học phải gồm $beaconCodeLength ký tự.');
  }
  return Uint8List.fromList([teacherPacketType, ...ascii.encode(beaconCode)]);
}

String? decodeTeacher(Uint8List bytes) {
  if (bytes.length != 1 + beaconCodeLength ||
      bytes.first != teacherPacketType) {
    return null;
  }
  final code = String.fromCharCodes(bytes.sublist(1));
  return _idChars.hasMatch(code) ? code : null;
}

Uint8List encodeStudent(String studentId, String tag) {
  final id = studentId.toUpperCase();
  if (id.isEmpty || id.length > maxStudentIdLength || !_idChars.hasMatch(id)) {
    throw ArgumentError('Mã sinh viên không hợp lệ.');
  }
  if (tag.length != tagLength || !_hex.hasMatch(tag)) {
    throw ArgumentError('Tag phải gồm $tagLength ký tự hex.');
  }
  final tagBytes = [
    for (var i = 0; i < tagLength; i += 2)
      int.parse(tag.substring(i, i + 2), radix: 16),
  ];
  return Uint8List.fromList([
    studentPacketType,
    ...tagBytes,
    ...ascii.encode(id),
  ]);
}

class StudentBeacon {
  const StudentBeacon(this.studentId, this.tag);
  final String studentId;
  final String tag;
}

StudentBeacon? decodeStudent(Uint8List bytes) {
  const header = 1 + tagLength ~/ 2;
  if (bytes.length <= header ||
      bytes.length > header + maxStudentIdLength ||
      bytes.first != studentPacketType) {
    return null;
  }
  final tag = [
    for (final b in bytes.sublist(1, header))
      b.toRadixString(16).padLeft(2, '0'),
  ].join();
  final id = String.fromCharCodes(bytes.sublist(header));
  if (!_idChars.hasMatch(id)) return null;
  return StudentBeacon(id, tag);
}
