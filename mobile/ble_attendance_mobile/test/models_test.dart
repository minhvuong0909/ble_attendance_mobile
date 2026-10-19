import 'package:ble_attendance_mobile/models/app_notification.dart';
import 'package:ble_attendance_mobile/models/attendance_history.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/class_info.dart';
import 'package:ble_attendance_mobile/models/class_stats.dart';
import 'package:ble_attendance_mobile/models/leave_request.dart';
import 'package:ble_attendance_mobile/models/session_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AttendanceStatus parses the three values with Vietnamese labels', () {
    expect(AttendanceStatus.parse('present').label, 'Có mặt');
    expect(AttendanceStatus.parse('absent').label, 'Vắng');
    expect(AttendanceStatus.parse('excused').label, 'Có phép');
    expect(() => AttendanceStatus.parse('late'), throwsFormatException);
  });

  test('ClassInfo.fromJson', () {
    final info = ClassInfo.fromJson({
      'id': 'c1',
      'course_id': 'k1',
      'course_code': 'PRM393',
      'course_name': 'Lập trình di động',
      'class_code': 'SE1901',
      'semester': 'FA26',
      'teacher_user_id': null,
      'teacher_name': null,
      'join_code': null,
      'max_absence_percent': 20,
      'rssi_threshold': -75,
      'student_count': 30,
    });
    expect(info.title, 'PRM393 · SE1901');
    expect(info.teacherName, isNull);
    expect(info.joinCode, isNull);
    expect(info.maxAbsencePercent, 20);
    expect(info.studentCount, 30);
  });

  test('SessionInfo.fromJson keeps the instant of a UTC timestamp', () {
    final session = SessionInfo.fromJson({
      'id': 's1',
      'class_id': 'c1',
      'class_code': 'SE1901',
      'course_code': 'PRM393',
      'course_name': 'Lập trình di động',
      'teacher_user_id': 't1',
      'beacon_code': 'abcd1234',
      'starts_at': '2026-10-18T03:00:00.123456Z',
      'ends_at': null,
      'is_active': true,
      'finalization_open': false,
      'beacon_secret': 'sec',
      'rssi_threshold': -80,
    });
    expect(
      session.startsAt.isAtSameMomentAs(
        DateTime.utc(2026, 10, 18, 3, 0, 0, 123, 456),
      ),
      isTrue,
    );
    expect(session.endsAt, isNull);
    expect(session.beaconSecret, 'sec');
    expect(session.rssiThreshold, -80);
    expect(session.isActive, isTrue);
    expect(session.finalizationOpen, isFalse);
  });

  test('AttendanceHistoryItem.fromJson with and without arrival time', () {
    final late = AttendanceHistoryItem.fromJson({
      'session_id': 's1',
      'starts_at': '2026-10-18T03:00:00Z',
      'ends_at': '2026-10-18T04:00:00Z',
      'status': 'present',
      'presence_ratio': 0.9,
      'first_seen_at': '2026-10-18T03:03:10Z',
      'late_minutes': 3,
    });
    expect(late.status, AttendanceStatus.present);
    expect(late.lateMinutes, 3);
    expect(late.firstSeenAt, isNotNull);

    final absent = AttendanceHistoryItem.fromJson({
      'session_id': 's2',
      'starts_at': '2026-10-19T03:00:00Z',
      'ends_at': null,
      'status': 'absent',
      'presence_ratio': 0,
      'first_seen_at': null,
      'late_minutes': null,
    });
    expect(absent.presenceRatio, 0.0);
    expect(absent.lateMinutes, isNull);
  });

  test('ClassStats.fromJson', () {
    final stats = ClassStats.fromJson({
      'class_id': 'c1',
      'course_code': 'PRM393',
      'course_name': 'Lập trình di động',
      'class_code': 'SE1901',
      'semester': 'FA26',
      'total_sessions': 3,
      'present': 2,
      'absent': 1,
      'excused': 0,
      'attendance_percent': 66.7,
      'absent_percent': 33.3,
      'max_absence_percent': 20,
      'warning': true,
    });
    expect(stats.title, 'PRM393 · SE1901');
    expect(stats.attendancePercent, 66.7);
    expect(stats.warning, isTrue);
  });

  test('LeaveRequest.fromJson', () {
    final leave = LeaveRequest.fromJson({
      'id': 7,
      'student_user_id': 'u1',
      'student_id': '25CE099',
      'student_name': 'An',
      'class_id': 'c1',
      'course_code': 'PRM393',
      'class_code': 'SE1901',
      'date': '2026-10-18',
      'reason': 'Bị ốm',
      'status': 'approved',
      'created_at': '2026-10-17T10:00:00Z',
      'reviewed_at': '2026-10-17T11:00:00Z',
      'review_note': 'Đã nhận giấy khám',
    });
    expect(leave.status, LeaveStatus.approved);
    expect(leave.status.label, 'Đã duyệt');
    expect(leave.date, DateTime(2026, 10, 18));
    expect(leave.reviewNote, 'Đã nhận giấy khám');
    expect(() => LeaveStatus.parse('cancelled'), throwsFormatException);
    expect(LeaveStatus.pending.label, 'Chờ duyệt');
    expect(LeaveStatus.rejected.label, 'Bị từ chối');
  });

  test('AppNotification.fromJson and copyWith', () {
    final n = AppNotification.fromJson({
      'id': 3,
      'type': 'finalization_open',
      'title': 'Mở chốt điểm danh',
      'body': 'Hãy xác nhận',
      'ref_id': 's1',
      'is_read': false,
      'created_at': '2026-10-18T03:00:00Z',
    });
    expect(n.isRead, isFalse);
    expect(n.copyWith(isRead: true).isRead, isTrue);
    expect(n.copyWith(isRead: true).id, 3);
  });
}
