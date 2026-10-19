import 'package:ble_attendance_mobile/data/admin_repository.dart';
import 'package:ble_attendance_mobile/data/attendance_repository.dart';
import 'package:ble_attendance_mobile/data/class_repository.dart';
import 'package:ble_attendance_mobile/data/device_authenticator.dart';
import 'package:ble_attendance_mobile/data/file_chooser.dart';
import 'package:ble_attendance_mobile/data/file_sharer.dart';
import 'package:ble_attendance_mobile/data/leave_repository.dart';
import 'package:ble_attendance_mobile/data/notification_repository.dart';
import 'package:ble_attendance_mobile/data/report_repository.dart';
import 'package:ble_attendance_mobile/data/session_repository.dart';
import 'package:ble_attendance_mobile/data/stats_repository.dart';
import 'package:ble_attendance_mobile/models/app_notification.dart';
import 'package:ble_attendance_mobile/models/attendance_record.dart';
import 'package:ble_attendance_mobile/models/auth_user.dart';
import 'package:ble_attendance_mobile/models/course.dart';
import 'package:ble_attendance_mobile/models/import_report.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
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
  String? joinCode,
  int studentCount = 30,
}) => ClassInfo(
  id: id,
  courseId: 'k1',
  courseCode: courseCode,
  courseName: courseName,
  classCode: classCode,
  semester: 'FA26',
  teacherUserId: 't1',
  teacherName: 'Co Lan',
  joinCode: joinCode,
  maxAbsencePercent: 20,
  rssiThreshold: -75,
  studentCount: studentCount,
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
  String classId = 'c1',
  String studentName = 'Nguyen Van A',
  DateTime? createdAt,
}) => LeaveRequest(
  id: id,
  studentUserId: 'u1',
  studentId: '25CE099',
  studentName: studentName,
  classId: classId,
  courseCode: 'PRM393',
  classCode: 'SE1901',
  date: date ?? DateTime(2026, 10, 18),
  reason: reason,
  status: status,
  createdAt: createdAt ?? DateTime(2026, 10, 17, 9, 0),
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

Course sampleCourse({
  String id = 'k1',
  String code = 'PRM393',
  String name = 'Lập trình di động',
  int? credits = 3,
}) => Course(id: id, code: code, name: name, credits: credits);

AuthUser sampleTeacher({
  String id = 't1',
  String teacherId = 'T001',
  String name = 'Co Lan',
}) => AuthUser(
  id: id,
  fullName: name,
  role: AppRole.teacher,
  studentId: null,
  teacherId: teacherId,
  mustChangePassword: true,
);

ImportReport sampleImportReport({
  bool dryRun = true,
  bool committed = false,
  int created = 2,
  int skipped = 1,
  List<ImportRow>? rows,
}) {
  final list =
      rows ??
      [
        const ImportRow(
          row: 2,
          status: ImportRowStatus.created,
          message: 'Tạo tài khoản và thêm vào lớp',
        ),
        const ImportRow(
          row: 3,
          status: ImportRowStatus.created,
          message: 'Thêm vào lớp',
        ),
        const ImportRow(
          row: 4,
          status: ImportRowStatus.skipped,
          message: 'Đã ở trong lớp',
        ),
      ];
  return ImportReport(
    kind: 'students',
    dryRun: dryRun,
    committed: committed,
    total: list.length,
    created: list.where((r) => r.status == ImportRowStatus.created).length,
    skipped: list.where((r) => r.status == ImportRowStatus.skipped).length,
    errors: list.where((r) => r.status == ImportRowStatus.error).length,
    rows: list,
  );
}

class FakeAdminRepository implements AdminRepository {
  Future<List<Course>> Function() onCourses = () async => [];
  Future<Course> Function(String code, String name, int? credits)
  onCreateCourse = (code, name, credits) async =>
      sampleCourse(code: code, name: name, credits: credits);
  Future<Course> Function(String id, String? name, int? credits)
  onUpdateCourse = (id, name, credits) async => sampleCourse(id: id);
  Future<void> Function(String id) onDeleteCourse = (_) async {};
  Future<List<ClassInfo>> Function() onAllClasses = () async => [];
  Future<ClassInfo> Function(Map<String, Object?> args) onCreateClass =
      (_) async => sampleClass();
  Future<ClassInfo> Function(String id, Map<String, Object?> args)
  onUpdateClass = (_, _) async => sampleClass();
  Future<void> Function(String id) onDeleteClass = (_) async {};
  Future<ClassInfo> Function(String classId, String teacherId) onAssign =
      (_, _) async => sampleClass();
  Future<List<AuthUser>> Function() onTeachers = () async => [];
  Future<AuthUser> Function(String teacherId, String fullName) onCreateTeacher =
      (id, name) async => sampleTeacher(teacherId: id, name: name);
  Future<void> Function(String userId) onResetPassword = (_) async {};
  Future<ImportReport> Function(
    String kind,
    String? classId,
    PickedFile file,
    bool dryRun,
  )
  onImport = (_, _, _, dryRun) async =>
      sampleImportReport(dryRun: dryRun, committed: !dryRun);
  Future<ExportFile> Function(String kind) onTemplate = (kind) async =>
      ExportFile(filename: '${kind}_template.csv', bytes: const [1]);

  int coursesCalls = 0;
  int classesCalls = 0;
  int teachersCalls = 0;
  final List<Map<String, Object?>> createdCourses = [];
  final List<Map<String, Object?>> updatedCourses = [];
  final List<String> deletedCourses = [];
  final List<Map<String, Object?>> createdClasses = [];
  final List<Map<String, Object?>> updatedClasses = [];
  final List<String> deletedClasses = [];
  final List<({String classId, String teacherId})> assigned = [];
  final List<Map<String, Object?>> createdTeachers = [];
  final List<String> resets = [];
  final List<({String kind, String? classId, String file, bool dryRun})>
  imports = [];
  final List<String> templates = [];

  @override
  Future<List<Course>> courses() {
    coursesCalls++;
    return onCourses();
  }

  @override
  Future<Course> createCourse({
    required String code,
    required String name,
    int? credits,
  }) {
    createdCourses.add({'code': code, 'name': name, 'credits': credits});
    return onCreateCourse(code, name, credits);
  }

  @override
  Future<Course> updateCourse(String id, {String? name, int? credits}) {
    updatedCourses.add({'id': id, 'name': name, 'credits': credits});
    return onUpdateCourse(id, name, credits);
  }

  @override
  Future<void> deleteCourse(String id) {
    deletedCourses.add(id);
    return onDeleteCourse(id);
  }

  @override
  Future<List<ClassInfo>> allClasses() {
    classesCalls++;
    return onAllClasses();
  }

  @override
  Future<ClassInfo> createClass({
    required String courseId,
    required String classCode,
    required String semester,
    String? teacherUserId,
    int maxAbsencePercent = 20,
    int rssiThreshold = -75,
  }) {
    final args = <String, Object?>{
      'courseId': courseId,
      'classCode': classCode,
      'semester': semester,
      'teacherUserId': teacherUserId,
      'maxAbsencePercent': maxAbsencePercent,
      'rssiThreshold': rssiThreshold,
    };
    createdClasses.add(args);
    return onCreateClass(args);
  }

  @override
  Future<ClassInfo> updateClass(
    String id, {
    String? classCode,
    String? semester,
    int? maxAbsencePercent,
    int? rssiThreshold,
  }) {
    final args = <String, Object?>{
      'classCode': classCode,
      'semester': semester,
      'maxAbsencePercent': maxAbsencePercent,
      'rssiThreshold': rssiThreshold,
    };
    updatedClasses.add({'id': id, ...args});
    return onUpdateClass(id, args);
  }

  @override
  Future<void> deleteClass(String id) {
    deletedClasses.add(id);
    return onDeleteClass(id);
  }

  @override
  Future<ClassInfo> assignTeacher(String classId, String teacherUserId) {
    assigned.add((classId: classId, teacherId: teacherUserId));
    return onAssign(classId, teacherUserId);
  }

  @override
  Future<List<AuthUser>> teachers() {
    teachersCalls++;
    return onTeachers();
  }

  @override
  Future<AuthUser> createTeacher({
    required String teacherId,
    required String fullName,
  }) {
    createdTeachers.add({'teacherId': teacherId, 'fullName': fullName});
    return onCreateTeacher(teacherId, fullName);
  }

  @override
  Future<void> resetPassword(String userId) {
    resets.add(userId);
    return onResetPassword(userId);
  }

  @override
  Future<ImportReport> importStudents(
    String classId,
    PickedFile file, {
    required bool dryRun,
  }) {
    imports.add((
      kind: 'students',
      classId: classId,
      file: file.name,
      dryRun: dryRun,
    ));
    return onImport('students', classId, file, dryRun);
  }

  @override
  Future<ImportReport> importTeachers(PickedFile file, {required bool dryRun}) {
    imports.add((
      kind: 'teachers',
      classId: null,
      file: file.name,
      dryRun: dryRun,
    ));
    return onImport('teachers', null, file, dryRun);
  }

  @override
  Future<ImportReport> importClasses(PickedFile file, {required bool dryRun}) {
    imports.add((
      kind: 'classes',
      classId: null,
      file: file.name,
      dryRun: dryRun,
    ));
    return onImport('classes', null, file, dryRun);
  }

  @override
  Future<ExportFile> downloadTemplate(String kind) {
    templates.add(kind);
    return onTemplate(kind);
  }
}

class FakeFileChooser implements FileChooser {
  PickedFile? next = PickedFile(name: 'data.csv', bytes: const [1, 2, 3]);
  int calls = 0;

  @override
  Future<PickedFile?> pick() async {
    calls++;
    return next;
  }
}
