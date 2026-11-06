import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/beacon_codec.dart';
import '../ble/ble_gateway.dart';
import '../core/app_constants.dart';
import '../data/detection_repository.dart';
import '../models/session_info.dart';
import 'auth_controller.dart';
import 'core_providers.dart';
import 'repositories.dart';

class TeacherBeaconState {
  const TeacherBeaconState({
    this.sessionId,
    this.problem,
    this.studentsSeen = 0,
    this.pending = 0,
    this.sent = 0,
    this.lastSentAt,
    this.sendError = false,
    this.scanError = false,
  });

  final String? sessionId;
  final BleReadiness? problem;
  final int studentsSeen;
  final int pending;
  final int sent;
  final DateTime? lastSentAt;
  final bool sendError;
  final bool scanError;

  bool get active => sessionId != null && problem == null;
}

const maxQueuedDetections = 500;
const _perStudentGap = Duration(seconds: 5);
const _maintenanceInterval = Duration(seconds: 5);

final teacherBeaconProvider =
    NotifierProvider<TeacherBeaconController, TeacherBeaconState>(
      TeacherBeaconController.new,
    );

/// Giảng viên: phát mã buổi học, quét gói của sinh viên và gửi lô detection mỗi 30 giây.
class TeacherBeaconController extends Notifier<TeacherBeaconState> {
  SessionInfo? _session;
  Timer? _timer;
  StreamSubscription<BleSighting>? _scanSub;
  final List<DetectionEntry> _queue = [];
  final Map<String, DateTime> _lastRecorded = {};
  DateTime? _lastFlush;
  bool _flushing = false;
  bool _advertising = false;
  String? _startingSessionId; // đang chờ ensureReady (xin quyền) cho buổi này
  int _generation = 0;

  BleGateway get _ble => ref.read(bleGatewayProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  TeacherBeaconState build() {
    ref.onDispose(_cancel);
    ref.listen(authControllerProvider, (_, next) {
      if (next.status != AuthStatus.authenticated) stop();
    });
    return const TeacherBeaconState();
  }

  Future<void> sync(SessionInfo? session) async {
    if (session == null || !session.isActive) {
      await stop();
      return;
    }
    if (_session?.id == session.id &&
        (_timer != null ||
            state.problem != null ||
            _startingSessionId == session.id)) {
      return;
    }
    await _start(session);
  }

  Future<void> retry() async {
    final session = _session;
    if (session != null) await _start(session);
  }

  Future<void> _start(SessionInfo session) async {
    await _teardown();
    final generation = ++_generation;
    _session = session;
    _lastFlush = _now();
    state = TeacherBeaconState(sessionId: session.id);
    _startingSessionId = session.id;
    final BleReadiness readiness;
    try {
      readiness = await _ble.ensureReady(advertise: true);
    } finally {
      if (generation == _generation) _startingSessionId = null;
    }
    if (generation != _generation) return;
    if (readiness != BleReadiness.ready) {
      state = TeacherBeaconState(sessionId: session.id, problem: readiness);
      return;
    }
    await _ble.startKeepAlive('Đang điểm danh ${session.courseCode}');
    try {
      await _ble.startAdvertising(encodeTeacher(session.beaconCode));
      _advertising = true;
    } catch (_) {
      // Vẫn quét được; _maintain thử phát lại.
    }
    if (generation != _generation) return;
    _listen(generation);
    _timer = Timer.periodic(_maintenanceInterval, (_) => _maintain());
  }

  void _listen(int generation) {
    _scanSub = _ble.scan().listen(
      _onSighting,
      onError: (_) {
        if (generation != _generation) return;
        state = _copy(scanError: true);
        _scanSub?.cancel();
        _scanSub = null;
      },
    );
  }

  void _onSighting(BleSighting sighting) {
    final session = _session;
    if (session == null) return;
    final student = decodeStudent(sighting.payload);
    if (student == null) return;
    final now = _now();
    final last = _lastRecorded[student.studentId];
    if (last != null && now.difference(last) < _perStudentGap) return;
    _lastRecorded[student.studentId] = now;
    _queue.add(
      DetectionEntry(
        sessionId: session.id,
        studentId: student.studentId,
        bucket: bucketOf(now),
        tag: student.tag,
        rssi: sighting.rssi,
        observedAt: now,
      ),
    );
    if (_queue.length > maxQueuedDetections) {
      _queue.removeRange(0, _queue.length - maxQueuedDetections);
    }
    state = _copy(
      studentsSeen: _lastRecorded.length,
      pending: _queue.length,
      scanError: false,
    );
  }

  Future<void> _maintain() async {
    final session = _session;
    if (session == null) return;
    if (!_advertising) {
      try {
        await _ble.startAdvertising(encodeTeacher(session.beaconCode));
        _advertising = true;
      } catch (_) {}
    }
    if (_scanSub == null) _listen(_generation);
    final last = _lastFlush;
    if (last == null ||
        _now().difference(last) >= teacherDetectionBatchInterval) {
      await flush();
    }
  }

  /// Gửi các detection đang chờ; lỗi thì giữ lại để gửi ở lần sau.
  Future<void> flush() async {
    if (_flushing) return;
    _lastFlush = _now();
    if (_queue.isEmpty) return;
    _flushing = true;
    final batch = List<DetectionEntry>.of(_queue);
    try {
      await ref.read(detectionRepositoryProvider).postBatch(batch);
      _queue.removeRange(0, batch.length);
      state = _copy(
        pending: _queue.length,
        sent: state.sent + batch.length,
        lastSentAt: _now(),
        sendError: false,
      );
    } catch (_) {
      state = _copy(sendError: true);
    } finally {
      _flushing = false;
    }
  }

  TeacherBeaconState _copy({
    int? studentsSeen,
    int? pending,
    int? sent,
    DateTime? lastSentAt,
    bool? sendError,
    bool? scanError,
  }) => TeacherBeaconState(
    sessionId: state.sessionId,
    problem: state.problem,
    studentsSeen: studentsSeen ?? state.studentsSeen,
    pending: pending ?? state.pending,
    sent: sent ?? state.sent,
    lastSentAt: lastSentAt ?? state.lastSentAt,
    sendError: sendError ?? state.sendError,
    scanError: scanError ?? state.scanError,
  );

  Future<void> stop() async {
    if (_session == null) return;
    if (_queue.isNotEmpty) await flush();
    await _teardown();
    _session = null;
    _queue.clear();
    _lastRecorded.clear();
    state = const TeacherBeaconState();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _scanSub?.cancel();
    _scanSub = null;
  }

  Future<void> _teardown() async {
    _generation++;
    _cancel();
    // Chỉ dừng phát khi đã thật sự phát: gọi plugin khi chưa có quyền sẽ kích hoạt
    // vòng xin quyền đệ quy trong flutter_ble_peripheral và làm app sập.
    final wasAdvertising = _advertising;
    _advertising = false;
    if (wasAdvertising) {
      try {
        await _ble.stopAdvertising();
      } catch (_) {}
    }
    if (_session != null) {
      try {
        await _ble.stopKeepAlive();
      } catch (_) {}
    }
  }
}
