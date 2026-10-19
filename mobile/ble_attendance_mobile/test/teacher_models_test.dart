import 'package:ble_attendance_mobile/models/attendance_record.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/class_report.dart';
import 'package:ble_attendance_mobile/models/student_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StudentInfo.fromJson', () {
    final s = StudentInfo.fromJson({
      'id': 'u1',
      'student_id': '25CE099',
      'full_name': 'An',
    });
    expect(s.studentId, '25CE099');
    expect(s.fullName, 'An');
    expect(
      StudentInfo.fromJson({
        'id': 'u2',
        'student_id': null,
        'full_name': 'B',
      }).studentId,
      isNull,
    );
  });

  test('SessionAttendance.fromJson parses records', () {
    final a = SessionAttendance.fromJson({
      'session_id': 's1',
      'class_id': 'c1',
      'total_students': 2,
      'present_students': 1,
      'records': [
        {
          'student_user_id': 'u1',
          'student_id': '25CE099',
          'student_name': 'An',
          'detection_count': 12,
          'presence_ratio': 0.9,
          'status': 'present',
          'finalized': true,
          'first_seen_at': '2026-10-18T03:03:10Z',
          'overridden': false,
          'override_reason': null,
        },
        {
          'student_user_id': 'u2',
          'student_id': '25CE100',
          'student_name': 'Binh',
          'detection_count': 0,
          'presence_ratio': 0,
          'status': 'excused',
          'finalized': false,
          'first_seen_at': null,
          'overridden': true,
          'override_reason': 'Có giấy phép',
        },
      ],
    });
    expect(a.totalStudents, 2);
    expect(a.presentStudents, 1);
    expect(a.records[0].status, AttendanceStatus.present);
    expect(a.records[0].firstSeenAt, isNotNull);
    expect(a.records[1].overridden, isTrue);
    expect(a.records[1].overrideReason, 'Có giấy phép');
    expect(a.records[1].presenceRatio, 0.0);
  });

  test('ClassReport.fromJson keeps null cells', () {
    final r = ClassReport.fromJson({
      'class_id': 'c1',
      'course_code': 'PRM393',
      'course_name': 'Lập trình di động',
      'class_code': 'SE1901',
      'semester': 'FA26',
      'sessions': [
        {'id': 's1', 'starts_at': '2026-10-01T03:00:00Z'},
        {'id': 's2', 'starts_at': '2026-10-02T03:00:00Z'},
      ],
      'students': [
        {
          'student_user_id': 'u1',
          'student_id': '25CE099',
          'student_name': 'An',
          'cells': ['present', null],
          'present': 1,
          'absent': 0,
          'excused': 0,
          'attendance_percent': 100.0,
          'absent_percent': 0.0,
          'warning': false,
        },
      ],
      'average_attendance_percent': 100,
    });
    expect(r.title, 'PRM393 · SE1901');
    expect(r.sessions, hasLength(2));
    expect(r.students.single.cells, [AttendanceStatus.present, null]);
    expect(r.averageAttendancePercent, 100.0);
  });
}
