import 'package:ble_attendance_mobile/data/attendance_repository.dart';
import 'package:ble_attendance_mobile/data/class_repository.dart';
import 'package:ble_attendance_mobile/data/device_authenticator.dart';
import 'package:ble_attendance_mobile/data/file_sharer.dart';
import 'package:ble_attendance_mobile/data/leave_repository.dart';
import 'package:ble_attendance_mobile/data/notification_repository.dart';
import 'package:ble_attendance_mobile/data/report_repository.dart';
import 'package:ble_attendance_mobile/data/session_repository.dart';
import 'package:ble_attendance_mobile/data/stats_repository.dart';
import 'package:ble_attendance_mobile/models/app_notification.dart';
import 'package:ble_attendance_mobile/models/attendance_record.dart';
import 'package:ble_attendance_mobile/models/class_report.dart';
import 'package:ble_attendance_mobile/models/export_file.dart';
import 'package:ble_attendance_mobile/models/student_info.dart';
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

StudentInfo sampleStudent({
  String id = 'u1',
  String studentId = '25CE099',
  String name = 'Nguyen Van A',
}) => StudentInfo(id: id, studentId: studentId, fullName: name);

AttendanceRecord sampleRecord({
  String id = 'u1',
  String studentId = '25CE099',
  String name = 'Nguyen Van A',
  AttendanceStatus status = AttendanceStatus.absent,
  double ratio = 0.0,
  int detections = 0,
  bool finalized = false,
  DateTime? firstSeenAt,
  bool overridden = false,
  String? reason,
}) => AttendanceRecord(
  studentUserId: id,
  studentId: studentId,
  studentName: name,
  detectionCount: detections,
  presenceRatio: ratio,
  status: status,
  finalized: finalized,
  firstSeenAt: firstSeenAt,
  overridden: overridden,
  overrideReason: reason,
);

SessionAttendance sampleAttendance({
  String sessionId = 's1',
  List<AttendanceRecord>? records,
  int? present,
}) {
  final list = records ?? [sampleRecord()];
  return SessionAttendance(
    sessionId: sessionId,
    classId: 'c1',
    totalStudents: list.length,
    presentStudents:
        present ??
        list.where((r) => r.status == AttendanceStatus.present).length,
    records: list,
  );
}

ClassReport sampleReport({
  List<ReportSession>? sessions,
  List<ReportStudent>? students,
  double average = 100.0,
}) => ClassReport(
  classId: 'c1',
  courseCode: 'PRM393',
  courseName: 'Lập trình di động',
  classCode: 'SE1901',
  semester: 'FA26',
  sessions: sessions ?? [],
  students: students ?? [],
  averageAttendancePercent: average,
);

ReportStudent sampleReportStudent({
  String id = 'u1',
  String studentId = '25CE099',
  String name = 'Nguyen Van A',
  List<AttendanceStatus?> cells = const [],
  int present = 0,
  int absent = 0,
  int excused = 0,
  double percent = 100.0,
  bool warning = false,
}) => ReportStudent(
  studentUserId: id,
  studentId: studentId,
  studentName: name,
  cells: cells,
  present: present,
  absent: absent,
  excused: excused,
  attendancePercent: percent,
  absentPercent: 100 - percent,
  warning: warning,
);

class FakeClassRepository implements ClassRepository {
  Future<List<ClassInfo>> Function() onMyClasses = () async => [];
  Future<ClassInfo> Function(String joinCode) onJoin = (_) async =>
      sampleClass();
  final List<String> joined = [];
  int myClassesCalls = 0;
  Future<List<StudentInfo>> Function(String classId) onStudents = (_) async =>
      [];

  @override
  Future<List<StudentInfo>> classStudents(String classId) =>
      onStudents(classId);

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
  Future<SessionInfo> Function(String classId) onStart = (_) async =>
      sampleSession();
  Future<SessionInfo> Function(String sessionId) onEnd = (_) async =>
      sampleSession();
  Future<SessionInfo> Function(String sessionId) onOpen = (_) async =>
      sampleSession(finalizationOpen: true);
  Future<List<SessionInfo>> Function(String classId) onClassSessions =
      (_) async => [];
  final List<String> started = [];
  final List<String> ended = [];
  final List<String> opened = [];

  @override
  Future<SessionInfo> startSession(String classId) {
    started.add(classId);
    return onStart(classId);
  }

  @override
  Future<SessionInfo> endSession(String sessionId) {
    ended.add(sessionId);
    return onEnd(sessionId);
  }

  @override
  Future<SessionInfo> openFinalization(String sessionId) {
    opened.add(sessionId);
    return onOpen(sessionId);
  }

  @override
  Future<List<SessionInfo>> classSessions(String classId) =>
      onClassSessions(classId);

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
  Future<List<LeaveRequest>> Function(String classId, LeaveStatus? status)
  onClassRequests = (_, _) async => [];
  Future<LeaveRequest> Function(int leaveId, String decision, String? note)
  onReview = (_, _, _) async => sampleLeave();
  final List<({int leaveId, String decision, String? note})> reviewed = [];
  int classRequestCalls = 0;

  @override
  Future<List<LeaveRequest>> classRequests(
    String classId, {
    LeaveStatus? status,
  }) {
    classRequestCalls++;
    return onClassRequests(classId, status);
  }

  @override
  Future<LeaveRequest> review({
    required int leaveId,
    required String decision,
    String? note,
  }) {
    reviewed.add((leaveId: leaveId, decision: decision, note: note));
    return onReview(leaveId, decision, note);
  }

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

class FakeAttendanceRepository implements AttendanceRepository {
  Future<SessionAttendance> Function(String sessionId) onAttendance =
      (_) async => sampleAttendance();
  Future<void> Function(
    String sessionId,
    String studentUserId,
    AttendanceStatus status,
    String reason,
  )
  onOverride = (_, _, _, _) async {};
  int attendanceCalls = 0;
  final List<
    ({
      String sessionId,
      String studentUserId,
      AttendanceStatus status,
      String reason,
    })
  >
  overrides = [];

  @override
  Future<SessionAttendance> sessionAttendance(String sessionId) {
    attendanceCalls++;
    return onAttendance(sessionId);
  }

  @override
  Future<void> overrideStatus({
    required String sessionId,
    required String studentUserId,
    required AttendanceStatus status,
    required String reason,
  }) {
    overrides.add((
      sessionId: sessionId,
      studentUserId: studentUserId,
      status: status,
      reason: reason,
    ));
    return onOverride(sessionId, studentUserId, status, reason);
  }
}

class FakeReportRepository implements ReportRepository {
  Future<ClassReport> Function(String classId) onReport = (_) async =>
      sampleReport();
  Future<ExportFile> Function() onExport = () async =>
      const ExportFile(filename: 'attendance.xlsx', bytes: [1, 2, 3]);
  final List<String> exportedClasses = [];
  final List<String> exportedSessions = [];
  int reportCalls = 0;

  @override
  Future<ClassReport> classReport(String classId) {
    reportCalls++;
    return onReport(classId);
  }

  @override
  Future<ExportFile> exportClass(String classId) {
    exportedClasses.add(classId);
    return onExport();
  }

  @override
  Future<ExportFile> exportSession(String sessionId) {
    exportedSessions.add(sessionId);
    return onExport();
  }
}

class FakeFileSharer implements FileSharer {
  final List<({String filename, List<int> bytes})> shared = [];

  @override
  Future<void> share(String filename, List<int> bytes) async {
    shared.add((filename: filename, bytes: bytes));
  }
}
