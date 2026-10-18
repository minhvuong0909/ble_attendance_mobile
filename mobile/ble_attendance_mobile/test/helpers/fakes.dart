import 'package:ble_attendance_mobile/data/class_repository.dart';
import 'package:ble_attendance_mobile/data/device_authenticator.dart';
import 'package:ble_attendance_mobile/data/leave_repository.dart';
import 'package:ble_attendance_mobile/data/notification_repository.dart';
import 'package:ble_attendance_mobile/data/session_repository.dart';
import 'package:ble_attendance_mobile/data/stats_repository.dart';
import 'package:ble_attendance_mobile/models/app_notification.dart';
import 'package:ble_attendance_mobile/models/attendance_history.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/class_info.dart';
import 'package:ble_attendance_mobile/models/class_stats.dart';
import 'package:ble_attendance_mobile/models/leave_request.dart';
import 'package:ble_attendance_mobile/models/session_info.dart';

ClassInfo sampleClass({
  String id = 'c1',
  String classCode = 'SE1901',
  String courseCode = 'PRM393',
  String courseName = 'Lập trình di động',
}) => ClassInfo(
  id: id,
  courseId: 'k1',
  courseCode: courseCode,
  courseName: courseName,
  classCode: classCode,
  semester: 'FA26',
  teacherUserId: 't1',
  teacherName: 'Co Lan',
  joinCode: null,
  maxAbsencePercent: 20,
  rssiThreshold: -75,
  studentCount: 30,
);

SessionInfo sampleSession({bool finalizationOpen = false, String id = 's1'}) =>
    SessionInfo(
      id: id,
      classId: 'c1',
      classCode: 'SE1901',
      courseCode: 'PRM393',
      courseName: 'Lập trình di động',
      teacherUserId: 't1',
      beaconCode: 'abcd1234',
      startsAt: DateTime(2026, 10, 18, 10, 0),
      endsAt: null,
      isActive: true,
      finalizationOpen: finalizationOpen,
      beaconSecret: 'secret',
    );

ClassStats sampleStats({
  String classId = 'c1',
  String classCode = 'SE1901',
  double attendance = 80.0,
  bool warning = false,
  int total = 5,
}) => ClassStats(
  classId: classId,
  courseCode: 'PRM393',
  courseName: 'Lập trình di động',
  classCode: classCode,
  semester: 'FA26',
  totalSessions: total,
  present: 3,
  absent: 1,
  excused: 1,
  attendancePercent: attendance,
  absentPercent: 20.0,
  maxAbsencePercent: 20,
  warning: warning,
);

AttendanceHistoryItem sampleHistory({
  String sessionId = 's1',
  DateTime? startsAt,
  AttendanceStatus status = AttendanceStatus.present,
  double ratio = 0.9,
  int? lateMinutes,
}) => AttendanceHistoryItem(
  sessionId: sessionId,
  startsAt: startsAt ?? DateTime(2026, 10, 18, 10, 0),
  endsAt: null,
  status: status,
  presenceRatio: ratio,
  firstSeenAt: null,
  lateMinutes: lateMinutes,
);

LeaveRequest sampleLeave({
  int id = 1,
  LeaveStatus status = LeaveStatus.pending,
  String reason = 'Bị ốm phải đi khám',
  String? note,
  DateTime? date,
}) => LeaveRequest(
  id: id,
  studentUserId: 'u1',
  studentId: '25CE099',
  studentName: 'Nguyen Van A',
  classId: 'c1',
  courseCode: 'PRM393',
  classCode: 'SE1901',
  date: date ?? DateTime(2026, 10, 18),
  reason: reason,
  status: status,
  createdAt: DateTime(2026, 10, 17, 9, 0),
  reviewedAt: null,
  reviewNote: note,
);

AppNotification sampleNotification({
  int id = 1,
  bool isRead = false,
  String title = 'Mở chốt điểm danh',
  String type = 'finalization_open',
}) => AppNotification(
  id: id,
  type: type,
  title: title,
  body: 'Hãy xác nhận ngay',
  refId: 's1',
  isRead: isRead,
  createdAt: DateTime(2026, 10, 18, 10, 30),
);

class FakeClassRepository implements ClassRepository {
  Future<List<ClassInfo>> Function() onMyClasses = () async => [];
  Future<ClassInfo> Function(String joinCode) onJoin = (_) async =>
      sampleClass();
  final List<String> joined = [];
  int myClassesCalls = 0;

  @override
  Future<List<ClassInfo>> myClasses() {
    myClassesCalls++;
    return onMyClasses();
  }

  @override
  Future<ClassInfo> join(String joinCode) {
    joined.add(joinCode);
    return onJoin(joinCode);
  }
}

class FakeSessionRepository implements SessionRepository {
  Future<SessionInfo?> Function() onActive = () async => null;
  Future<void> Function(String sessionId) onFinalize = (_) async {};
  int activeCalls = 0;
  final List<String> finalized = [];

  @override
  Future<SessionInfo?> activeSession() {
    activeCalls++;
    return onActive();
  }

  @override
  Future<void> finalize(String sessionId) {
    finalized.add(sessionId);
    return onFinalize(sessionId);
  }
}

class FakeStatsRepository implements StatsRepository {
  Future<List<ClassStats>> Function() onStats = () async => [];
  Future<List<AttendanceHistoryItem>> Function(String classId) onHistory =
      (_) async => [];
  int statsCalls = 0;

  @override
  Future<List<ClassStats>> stats() {
    statsCalls++;
    return onStats();
  }

  @override
  Future<List<AttendanceHistoryItem>> history(String classId) =>
      onHistory(classId);
}

class FakeLeaveRepository implements LeaveRepository {
  Future<List<LeaveRequest>> Function() onMine = () async => [];
  Future<LeaveRequest> Function(String classId, DateTime date, String reason)
  onCreate = (classId, date, reason) async => sampleLeave();
  final List<({String classId, DateTime date, String reason})> created = [];
  int mineCalls = 0;

  @override
  Future<List<LeaveRequest>> mine() {
    mineCalls++;
    return onMine();
  }

  @override
  Future<LeaveRequest> create({
    required String classId,
    required DateTime date,
    required String reason,
  }) {
    created.add((classId: classId, date: date, reason: reason));
    return onCreate(classId, date, reason);
  }
}

class FakeNotificationRepository implements NotificationRepository {
  Future<List<AppNotification>> Function() onList = () async => [];
  Future<int> Function() onUnreadCount = () async => 0;
  Future<void> Function(int id) onMarkRead = (_) async {};
  Future<void> Function() onMarkAllRead = () async {};
  final List<int> markedRead = [];
  int markAllCalls = 0;
  int listCalls = 0;
  int countCalls = 0;

  @override
  Future<List<AppNotification>> list({bool unreadOnly = false}) {
    listCalls++;
    return onList();
  }

  @override
  Future<int> unreadCount() {
    countCalls++;
    return onUnreadCount();
  }

  @override
  Future<void> markRead(int id) {
    markedRead.add(id);
    return onMarkRead(id);
  }

  @override
  Future<void> markAllRead() {
    markAllCalls++;
    return onMarkAllRead();
  }
}

class FakeDeviceAuthenticator implements DeviceAuthenticator {
  Future<bool> Function(String reason) onAuthenticate = (_) async => true;
  int calls = 0;

  @override
  Future<bool> authenticate(String reason) {
    calls++;
    return onAuthenticate(reason);
  }
}
