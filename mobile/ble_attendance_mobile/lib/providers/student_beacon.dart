import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_gateway.dart';
import '../ble/beacon_codec.dart';
import '../core/app_constants.dart';
import '../models/session_info.dart';
import 'core_providers.dart';
import 'repositories.dart';

enum Proximity { unknown, near, far }

class StudentBeaconState {
  const StudentBeaconState({
    this.sessionId,
    this.problem,
    this.proximity = Proximity.unknown,
    this.rssi,
    this.scanError = false,
  });

  final String? sessionId;
  final BleReadiness? problem;
  final Proximity proximity;
  final int? rssi;
  final bool scanError;

  bool get active => sessionId != null && problem == null;
}

const _maintenanceInterval = Duration(seconds: 5);
const _signalLostAfter = Duration(seconds: 15);

final studentBeaconProvider =
    NotifierProvider<StudentBeaconController, StudentBeaconState>(
      StudentBeaconController.new,
    );

/// Sinh viên: phát tag HMAC của mình và quét tín hiệu máy giảng viên để biết gần/xa lớp.
class StudentBeaconController extends Notifier<StudentBeaconState> {
  SessionInfo? _session;
  String? _studentId;
  Timer? _timer;
  StreamSubscription<BleSighting>? _scanSub;
  int? _advertisedBucket;
  final List<int> _window = [];
  DateTime? _lastTeacherSeen;
  Proximity? _candidate;
  DateTime? _candidateSince;
  int _generation = 0;

  BleGateway get _ble => ref.read(bleGatewayProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  StudentBeaconState build() {
    ref.onDispose(_cancel);
    return const StudentBeaconState();
  }

  /// Đồng bộ với buổi học đang diễn ra (null hoặc đã kết thúc thì dừng).
  Future<void> sync(SessionInfo? session, String studentId) async {
    final usable =
        session != null && session.isActive && session.beaconSecret != null;
    if (!usable) {
      await stop();
      return;
    }
    if (_session?.id == session.id &&
        (_timer != null || state.problem != null)) {
      return;
    }
    await _start(session, studentId);
  }

  Future<void> retry() async {
    final session = _session;
    final id = _studentId;
    if (session != null && id != null) await _start(session, id);
  }

  Future<void> _start(SessionInfo session, String studentId) async {
    await _cancelAsync();
    final generation = ++_generation;
    _session = session;
    _studentId = studentId;
    state = StudentBeaconState(sessionId: session.id);
    final readiness = await _ble.ensureReady(advertise: true);
    if (generation != _generation) return;
    if (readiness != BleReadiness.ready) {
      state = StudentBeaconState(sessionId: session.id, problem: readiness);
      return;
    }
    await _ble.startKeepAlive('Đang điểm danh ${session.courseCode}');
    _advertise();
    _listen(generation);
    _timer = Timer.periodic(_maintenanceInterval, (_) => _maintain());
  }

  void _advertise() {
    final session = _session!;
    final bucket = bucketOf(_now());
    if (bucket == _advertisedBucket) return;
    _advertisedBucket = bucket;
    final tag = makeTag(session.beaconSecret!, bucket);
    unawaited(
      _ble.startAdvertising(encodeStudent(_studentId!, tag)).catchError((_) {
        _advertisedBucket = null; // thử lại ở lần bảo trì sau
      }),
    );
  }

  void _listen(int generation) {
    _scanSub = _ble.scan().listen(
      _onSighting,
      onError: (_) {
        if (generation != _generation) return;
        state = _copy(scanError: true);
        _scanSub?.cancel();
        _scanSub = null; // _maintain quét lại
      },
    );
  }

  void _onSighting(BleSighting sighting) {
    final code = decodeTeacher(sighting.payload);
    if (code == null || code != _session?.beaconCode) return;
    final now = _now();
    _lastTeacherSeen = now;
    _window.add(sighting.rssi);
    if (_window.length > rssiWindowSize) _window.removeAt(0);
    final sorted = [..._window]..sort();
    final median = sorted[sorted.length ~/ 2];
    final next = median > _session!.rssiThreshold
        ? Proximity.near
        : Proximity.far;
    _applyProximity(next, median, now);
  }

  void _applyProximity(Proximity next, int rssi, DateTime now) {
    if (state.proximity == Proximity.unknown || next == state.proximity) {
      _candidate = null;
      _candidateSince = null;
      state = _copy(proximity: next, rssi: rssi, scanError: false);
      return;
    }
    if (_candidate != next) {
      _candidate = next;
      _candidateSince = now;
    }
    if (now.difference(_candidateSince!) >= proximityDebounceDuration) {
      _candidate = null;
      _candidateSince = null;
      state = _copy(proximity: next, rssi: rssi, scanError: false);
    } else {
      state = _copy(rssi: rssi, scanError: false);
    }
  }

  void _maintain() {
    if (_session == null) return;
    _advertise();
    if (_scanSub == null) _listen(_generation);
    final seen = _lastTeacherSeen;
    if (seen != null &&
        _now().difference(seen) > _signalLostAfter &&
        state.proximity != Proximity.unknown) {
      _window.clear();
      state = _copy(proximity: Proximity.unknown, rssi: null);
    }
  }

  StudentBeaconState _copy({
    Proximity? proximity,
    int? rssi,
    bool? scanError,
  }) => StudentBeaconState(
    sessionId: state.sessionId,
    problem: state.problem,
    proximity: proximity ?? state.proximity,
    rssi: proximity == Proximity.unknown ? null : (rssi ?? state.rssi),
    scanError: scanError ?? state.scanError,
  );

  Future<void> stop() async {
    final had = _session != null;
    await _cancelAsync();
    _session = null;
    _studentId = null;
    if (had) state = const StudentBeaconState();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _scanSub?.cancel();
    _scanSub = null;
  }

  Future<void> _cancelAsync() async {
    _generation++;
    _cancel();
    _window.clear();
    _lastTeacherSeen = null;
    _candidate = null;
    _candidateSince = null;
    if (_advertisedBucket != null) {
      _advertisedBucket = null;
      try {
        await _ble.stopAdvertising();
        await _ble.stopKeepAlive();
      } catch (_) {}
    }
  }
}
