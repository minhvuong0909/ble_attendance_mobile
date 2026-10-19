import 'package:ble_attendance_mobile/ble/ble_gateway.dart';
import 'package:ble_attendance_mobile/ble/beacon_codec.dart';
import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/data/detection_repository.dart';
import 'package:ble_attendance_mobile/providers/core_providers.dart';
import 'package:ble_attendance_mobile/providers/repositories.dart';
import 'package:ble_attendance_mobile/providers/teacher_beacon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

class _Setup {
  _Setup() {
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        bleGatewayProvider.overrideWithValue(ble),
        detectionRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  }
  final ble = FakeBleGateway();
  final repo = FakeDetectionRepository();
  DateTime now = DateTime.utc(2026, 10, 18, 3, 0, 5);
  late final ProviderContainer container;
  TeacherBeaconController get controller =>
      container.read(teacherBeaconProvider.notifier);
  TeacherBeaconState get state => container.read(teacherBeaconProvider);

  void student(String id, int rssi, {String tag = 'deadbeef'}) =>
      ble.emit(encodeStudent(id, tag), rssi);
}

void main() {
  testWidgets('advertises the session code and starts scanning', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession());
    expect(decodeTeacher(s.ble.advertised.single), 'abcd1234');
    expect(s.ble.scanStarts, 1);
    expect(s.ble.keepAliveStarts, 1);
    await s.controller.stop();
  });

  testWidgets('sightings are deduplicated per student within 5 seconds', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession());
    s.student('25CE099', -60);
    s.student('25CE099', -62);
    s.student('25CE100', -70);
    await tester.pump();
    expect(s.state.studentsSeen, 2);
    expect(s.state.pending, 2);
    s.now = s.now.add(const Duration(seconds: 6));
    s.student('25CE099', -61);
    await tester.pump();
    expect(s.state.pending, 3);
    await s.controller.stop();
  });

  testWidgets('non-student packets are ignored', (tester) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession());
    s.ble.emit(encodeTeacher('abcd1234'), -40);
    await tester.pump();
    expect(s.state.pending, 0);
    await s.controller.stop();
  });

  testWidgets('a batch is posted every 30 seconds with bucket and tag', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession());
    s.student('25CE099', -60, tag: 'cafebabe');
    await tester.pump();
    s.now = s.now.add(const Duration(seconds: 29));
    await tester.pump(const Duration(seconds: 5));
    expect(s.repo.batches, isEmpty);
    s.now = s.now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 5));
    final entry = s.repo.batches.single.single;
    expect(entry.sessionId, 's1');
    expect(entry.studentId, '25CE099');
    expect(entry.tag, 'cafebabe');
    expect(entry.rssi, -60);
    expect(entry.bucket, bucketOf(DateTime.utc(2026, 10, 18, 3, 0, 5)));
    expect(s.state.pending, 0);
    expect(s.state.sent, 1);
    await s.controller.stop();
  });

  testWidgets('a failed post keeps the detections and retries', (tester) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    var fail = true;
    s.repo.onBatch = (entries) async {
      if (fail) throw ApiException('network', 'x');
      return BatchResult(recorded: entries.length, rejected: 0);
    };
    await s.controller.sync(sampleSession());
    s.student('25CE099', -60);
    await tester.pump();
    s.now = s.now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 5));
    expect(s.state.sendError, isTrue);
    expect(s.state.pending, 1);
    fail = false;
    s.now = s.now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 5));
    expect(s.state.sendError, isFalse);
    expect(s.state.pending, 0);
    expect(s.repo.batches.last.single.studentId, '25CE099');
    await s.controller.stop();
  });

  testWidgets('the queue is capped at 500 entries', (tester) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession());
    for (var i = 0; i < 520; i++) {
      s.student('S${i.toString().padLeft(4, '0')}', -60);
    }
    await tester.pump();
    expect(s.state.pending, maxQueuedDetections);
    await s.controller.stop();
  });

  testWidgets('stopping flushes what is left and stops the radio', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession());
    s.student('25CE099', -60);
    await tester.pump();
    await s.controller.sync(null);
    expect(s.repo.batches, hasLength(1));
    expect(s.ble.stops, 1);
    expect(s.ble.keepAliveStops, 1);
    expect(s.state.sessionId, isNull);
  });

  testWidgets('problems are reported and sync does not re-ask until retry', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    s.ble.readiness = BleReadiness.permissionDenied;
    await s.controller.sync(sampleSession());
    expect(s.state.problem, BleReadiness.permissionDenied);
    await s.controller.sync(sampleSession());
    expect(s.ble.scanStarts, 0);
    s.ble.readiness = BleReadiness.ready;
    await s.controller.retry();
    expect(s.state.active, isTrue);
    expect(s.ble.scanStarts, 1);
    await s.controller.stop();
  });

  testWidgets('re-syncing the same session does not restart', (tester) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession());
    await s.controller.sync(sampleSession());
    expect(s.ble.scanStarts, 1);
    expect(s.ble.advertised, hasLength(1));
    await s.controller.stop();
  });
}
