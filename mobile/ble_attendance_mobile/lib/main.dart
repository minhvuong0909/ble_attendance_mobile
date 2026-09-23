import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/app_constants.dart';
import 'models/app_role.dart';
import 'models/student_tally.dart';
import 'services/api_client.dart';

// ---------------------------------------------------------------------------
// Hằng số dùng chung được đặt trong core/app_constants.dart.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Điểm khởi chạy ứng dụng
// ---------------------------------------------------------------------------

void main() {
  runApp(const BleAttendanceApp());
}

class BleAttendanceApp extends StatelessWidget {
  const BleAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
      ),
      home: const LoginPage(),
    );
  }
}

// ===========================================================================
// MÀN HÌNH ĐĂNG NHẬP
// ===========================================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _serverUrlCtrl = TextEditingController();
  AppRole _role = AppRole.student;
  bool _isRegister = false;
  bool _loading = false;
  bool _ready = false;
  bool _wakingServer = false;
  int _wakeCountdown = 0;
  Timer? _wakeTimer;

  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _api.init();
    await _api.enablePersistentConnection();
    _serverUrlCtrl.text = _api.baseUrl;
    final token = await _api.readToken();
    if (token != null && token.isNotEmpty) {
      final roleName = await _api.readRole();
      if (!mounted) return;
      if (roleName == AppRole.teacher.name) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => TeacherPage(api: _api)),
        );
        return;
      }
      if (roleName == AppRole.student.name) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StudentPage(api: _api)),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _serverUrlCtrl.dispose();
    _wakeTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await _api.setBaseUrl(_serverUrlCtrl.text);
      if (_isRegister) {
        await _api.register(
          fullName: _nameCtrl.text.trim(),
          identifier: _identifierCtrl.text.trim().toUpperCase(),
          password: _passwordCtrl.text,
          role: _role,
        );
      }
      final token = await _api.login(
        identifier: _identifierCtrl.text.trim().toUpperCase(),
        password: _passwordCtrl.text,
      );
      await _api.saveToken(token);
      await _api.saveRole(_role.name);
      // Lưu mã để sinh viên phát BLE hoặc để hiển thị cho giảng viên.
      await _api.saveIdentifier(_identifierCtrl.text.trim().toUpperCase());
      if (!mounted) return;
      if (_role == AppRole.teacher) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => TeacherPage(api: _api)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StudentPage(api: _api)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _loading = true);
    try {
      await _api.setBaseUrl(_serverUrlCtrl.text);
      await _api.healthCheck();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server connection successful.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _wakeServer() async {
    await _api.setBaseUrl(_serverUrlCtrl.text);
    setState(() {
      _wakingServer = true;
      _wakeCountdown = 60;
    });
    _wakeTimer?.cancel();
    _wakeTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_wakeCountdown <= 0) {
        timer.cancel();
        setState(() => _wakingServer = false);
        return;
      }
      setState(() => _wakeCountdown--);
      // Kiểm tra lại trạng thái máy chủ sau mỗi 10 giây.
      if (_wakeCountdown % 10 == 0 || _wakeCountdown == 59) {
        try {
          await _api.healthCheck();
          timer.cancel();
          if (mounted) {
            setState(() {
              _wakingServer = false;
              _wakeCountdown = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Server is ready!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (_) {
          // Máy chủ vẫn đang khởi động, tiếp tục chờ.
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Attendance Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<AppRole>(
              segments: const [
                ButtonSegment(value: AppRole.student, label: Text('Student')),
                ButtonSegment(value: AppRole.teacher, label: Text('Teacher')),
              ],
              selected: {_role},
              onSelectionChanged: (set) => setState(() => _role = set.first),
            ),
            const SizedBox(height: 12),
            if (_isRegister)
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _identifierCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: _role == AppRole.teacher
                    ? 'Teacher ID (e.g. T001)'
                    : 'Student ID (e.g. 25CE099)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.1.10:8000',
              ),
            ),
            const SizedBox(height: 8),
            const Text('For real phones use http://<laptop-ip>:8000'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading || !_ready ? null : _submit,
              child: Text(
                _loading
                    ? 'Please wait...'
                    : (_isRegister ? 'Register and Login' : 'Login'),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: _loading || !_ready ? null : _testConnection,
              child: const Text('Test Connection'),
            ),
            const SizedBox(height: 4),
            // Đánh thức máy chủ khi dùng gói miễn phí của Render.
            OutlinedButton.icon(
              onPressed: _wakingServer || _loading || !_ready
                  ? null
                  : _wakeServer,
              icon: _wakingServer
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.power_settings_new),
              label: Text(
                _wakingServer
                    ? 'Waking server... ${_wakeCountdown}s'
                    : 'Wake Server (Render)',
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? 'Already have account? Login'
                    : 'New user? Register',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// MÀN HÌNH GIẢNG VIÊN
// ===========================================================================

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  final _subjectCtrl = TextEditingController(text: 'Distributed Systems');
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  String? _sessionId;
  String? _token;
  bool _loading = false;
  bool _isAdvertising = false;
  bool _finalizationOpen = false;
  bool _showEndConfirm = false;
  bool _isScanning = false;
  Map<String, dynamic>? _summary;
  Timer? _pollTimer;
  Timer? _batchTimer;
  StreamSubscription<DiscoveredDevice>? _scanSub;

  // Thống kê phát hiện sinh viên lưu tạm trên máy giảng viên.
  final Map<String, StudentTally> _studentTallies = {};

  // Hàng đợi các lần phát hiện trước khi gửi theo lô.
  final List<Map<String, dynamic>> _pendingDetections = [];

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _loadActiveSession();
    _startPolling();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _blePeripheral.stop();
    _scanSub?.cancel();
    _pollTimer?.cancel();
    _batchTimer?.cancel();
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(teacherPollInterval, (_) async {
      if (!mounted || _loading) return;
      await _loadActiveSession();
      if (_sessionId != null) {
        await _refreshSummary();
      }
    });
  }

  void _startBatchPosting() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(teacherDetectionBatchInterval, (_) async {
      if (_pendingDetections.isEmpty || _sessionId == null) return;
      await _flushDetections();
    });
  }

  Future<void> _flushDetections() async {
    if (_pendingDetections.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_pendingDetections);
    _pendingDetections.clear();
    try {
      await widget.api.submitDetectionBatch(batch);
    } catch (_) {
      // Đưa dữ liệu trở lại hàng đợi nếu gửi thất bại.
      _pendingDetections.insertAll(0, batch);
    }
  }

  Future<void> _startSession() async {
    setState(() => _loading = true);
    try {
      final permsOk = await _ensureBlePermissions();
      if (!permsOk) throw Exception('Bluetooth permissions are required.');

      // Yêu cầu bật Bluetooth nếu đang tắt.
      await _ensureBluetoothEnabled();

      final session = await widget.api.startSession(_subjectCtrl.text.trim());
      _sessionId = session['id'] as String;
      _token = session['token'] as String;
      _finalizationOpen = (session['finalization_open'] as bool?) ?? false;

      // Bắt đầu phát beacon BLE của giảng viên.
      final data = AdvertiseData(
        serviceUuid: teacherServiceUuid,
        includeDeviceName: false,
        manufacturerId: manufacturerId,
        manufacturerData: Uint8List.fromList(
          _encodeTeacherPayload(_token!, _subjectCtrl.text.trim()),
        ),
      );
      await _blePeripheral.start(advertiseData: data);
      _isAdvertising = true;

      // Bắt đầu quét beacon của sinh viên.
      _startStudentScan();
      _startBatchPosting();

      // Duy trì tác vụ BLE bằng dịch vụ nền trên Android.
      _startForegroundService('Teaching: ${_subjectCtrl.text.trim()}');

      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startStudentScan() {
    _scanSub?.cancel();
    _isScanning = true;
    _scanSub = _ble
        .scanForDevices(
          withServices: const [],
          scanMode: ScanMode.lowLatency,
          requireLocationServicesEnabled: false,
        )
        .listen(
          (device) {
            final studentId = _extractStudentId(device);
            if (studentId == null || _sessionId == null) return;

            final rssi = device.rssi;
            final ok = rssi > rssiThreshold;
            final now = DateTime.now();

            // Cập nhật thống kê cục bộ.
            final tally = _studentTallies.putIfAbsent(
              studentId,
              () => StudentTally(studentId: studentId),
            );
            tally.total++;
            if (ok) tally.hits++;
            tally.latestRssi = rssi;
            tally.latestAt = now;
            tally.inRange = ok;

            // Đưa lần phát hiện vào hàng đợi gửi theo lô.
            _pendingDetections.add({
              'session_id': _sessionId,
              'student_identifier': studentId,
              'rssi': rssi,
              'proximity_ok': ok,
            });

            if (mounted) setState(() {});
          },
          onError: (_) {
            if (mounted) setState(() => _isScanning = false);
            _scheduleStudentScanRetry();
          },
          onDone: () {
            if (mounted) setState(() => _isScanning = false);
            _scheduleStudentScanRetry();
          },
        );
  }

  void _scheduleStudentScanRetry() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isScanning && _sessionId != null) {
        _startStudentScan();
      }
    });
  }

  String? _extractStudentId(DiscoveredDevice device) {
    // Thiết bị sinh viên đặt mã sinh viên trong manufacturer data.
    if (device.manufacturerData.isEmpty) return null;

    try {
      final bytes = device.manufacturerData;
      // Hai byte đầu là mã nhà sản xuất, phần còn lại là mã sinh viên.
      if (bytes.length < 4) return null;
      final idBytes = bytes.sublist(2);
      final rawId = utf8.decode(idBytes, allowMalformed: true).trim();
      // Chỉ chấp nhận mã gồm chữ và số, dài từ 5 đến 12 ký tự.
      if (rawId.length >= 5 &&
          rawId.length <= 12 &&
          RegExp(r'^[A-Z0-9]+$').hasMatch(rawId)) {
        return rawId;
      }
    } catch (_) {}
    return null;
  }

  List<int> _encodeTeacherPayload(String token, String subject) {
    // Định dạng: token tối đa 16 ký tự, dấu | và tên môn tối đa 10 ký tự.
    final tokenPart = token.length > 16 ? token.substring(0, 16) : token;
    final subjectPart = subject.length > 10
        ? subject.substring(0, 10)
        : subject;
    return utf8.encode('$tokenPart|$subjectPart');
  }

  Future<void> _endSession() async {
    var sessionId = _sessionId;
    if (sessionId == null) {
      try {
        final active = await widget.api.getActiveSession();
        sessionId = active['id'] as String;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active session to end.')),
          );
        }
        return;
      }
    }

    setState(() => _loading = true);
    try {
      // Gửi hết các lần phát hiện còn lại trước khi kết thúc.
      await _flushDetections();
      await widget.api.endSession(sessionId);
      await _blePeripheral.stop();
      _scanSub?.cancel();
      _batchTimer?.cancel();
      _isAdvertising = false;
      _isScanning = false;
      await _refreshSummary();
      FlutterForegroundTask.stopService();
      if (mounted) {
        setState(() {
          _sessionId = null;
          _token = null;
          _finalizationOpen = false;
          _showEndConfirm = false;
          _studentTallies.clear();
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshSummary() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    try {
      final summary = await widget.api.getAttendanceSummary(sessionId);
      if (mounted) setState(() => _summary = summary);
    } catch (_) {}
  }

  Future<void> _loadActiveSession() async {
    try {
      final session = await widget.api.getActiveSession();
      if (!mounted) return;
      setState(() {
        _sessionId = session['id'] as String;
        _token = session['token'] as String;
        _finalizationOpen = (session['finalization_open'] as bool?) ?? false;
      });
    } catch (_) {}
  }

  Future<void> _openFinalization() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() => _loading = true);
    try {
      final session = await widget.api.openFinalization(sessionId);
      if (!mounted) return;
      setState(() {
        _finalizationOpen = (session['finalization_open'] as bool?) ?? true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finalization opened for students.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadAttendanceReport() async {
    final sessionId = _sessionId ?? _summary?['session_id'];
    if (sessionId == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await widget.api.downloadAttendanceExcel(
        sessionId as String,
      );
      // Lưu báo cáo vào thư mục tải xuống trên Android.
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(
        '${dir.path}/attendance_${sessionId.toString().substring(0, 8)}.xlsx',
      );
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _blePeripheral.stop();
    _scanSub?.cancel();
    _batchTimer?.cancel();
    FlutterForegroundTask.stopService();
    await widget.api.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedStudents = _studentTallies.values.toList()
      ..sort((a, b) => b.hits.compareTo(a.hits));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tên môn học.
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),

            // Bắt đầu buổi học.
            FilledButton(
              onPressed: _loading || _sessionId != null ? null : _startSession,
              child: const Text('Start Session + BLE Broadcast'),
            ),
            const SizedBox(height: 8),

            // Mở giai đoạn chốt điểm danh.
            FilledButton.tonal(
              onPressed: _loading || _sessionId == null || _finalizationOpen
                  ? null
                  : _openFinalization,
              child: const Text('Open Finalization for Students'),
            ),
            const SizedBox(height: 8),

            // Khôi phục buổi học đang diễn ra.
            OutlinedButton(
              onPressed: _loadActiveSession,
              child: const Text('Recover Active Session'),
            ),
            const SizedBox(height: 8),

            // Tải báo cáo điểm danh.
            OutlinedButton.icon(
              onPressed: _loading ? null : _downloadAttendanceReport,
              icon: const Icon(Icons.download),
              label: const Text('Download Attendance (Excel)'),
            ),

            const SizedBox(height: 12),

            // Trạng thái BLE.
            Text('Session: ${_sessionId != null ? "ACTIVE" : "None"}'),
            Text(
              'BLE: ${_isAdvertising ? "📡 Advertising" : "OFF"} '
              '| Scan: ${_isScanning ? "🔍 ON" : "OFF"}',
            ),
            Text('Finalization: ${_finalizationOpen ? "OPEN" : "CLOSED"}'),
            if (_summary != null)
              Text(
                'Attendance: ${_summary!['present_students']}/${_summary!['total_students']} present',
              ),

            const SizedBox(height: 12),
            Text(
              'Students detected (${sortedStudents.length}):',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // Danh sách sinh viên đã được phát hiện.
            Expanded(
              child: ListView.builder(
                itemCount: sortedStudents.length,
                itemBuilder: (context, index) {
                  final s = sortedStudents[index];
                  return ListTile(
                    dense: true,
                    title: Text(s.studentId),
                    subtitle: Text(
                      'Hits: ${s.hits}/${s.total} '
                      '| RSSI: ${s.latestRssi} '
                      '| ${_timeAgo(s.latestAt)}',
                    ),
                    trailing: Icon(
                      s.inRange ? Icons.check_circle : Icons.cancel,
                      color: s.inRange ? Colors.green : Colors.red,
                    ),
                  );
                },
              ),
            ),

            // Đặt nút kết thúc ở cuối màn hình để tránh bấm nhầm.
            const Divider(height: 32),
            const SizedBox(height: 8),
            if (_sessionId != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _loading
                    ? null
                    : () => setState(() => _showEndConfirm = !_showEndConfirm),
                child: Text(
                  _showEndConfirm
                      ? 'Cancel End Confirmation'
                      : 'Show End Session Button',
                ),
              ),
            if (_showEndConfirm && _sessionId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _loading ? null : _endSession,
                  child: const Text('Confirm End Session'),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '-';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }
}

// ===========================================================================
// MÀN HÌNH SINH VIÊN
// ===========================================================================

class StudentPage extends StatefulWidget {
  const StudentPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final LocalAuthentication _localAuth = LocalAuthentication();

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<BleStatus>? _bleStatusSub;

  String? _sessionId;
  String? _subject;
  String? _studentIdentifier;
  int? _latestRssi;
  bool _scanning = false;
  bool _advertising = false;
  bool _finalizationOpen = false;
  bool _blePermissionsGranted = true;
  String? _scanError;
  Timer? _scanRetryTimer;
  Timer? _sessionPollTimer;
  BleStatus _bleStatus = BleStatus.unknown;

  // Trạng thái khoảng cách sau khi chống dao động tín hiệu.
  bool? _proximityOk;
  bool? _rawProximityOk;
  DateTime? _rawProximityChangeAt;

  // Cửa sổ trượt dùng để làm mượt RSSI.
  final List<int> _rssiWindow = [];

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _watchBleStatus();
    _bootstrap();
    _startSessionPolling();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _bleStatusSub?.cancel();
    _scanRetryTimer?.cancel();
    _sessionPollTimer?.cancel();
    _blePeripheral.stop();
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  void _startSessionPolling() {
    _sessionPollTimer?.cancel();
    _sessionPollTimer = Timer.periodic(studentSessionPollInterval, (_) async {
      if (!mounted) return;
      await _loadActiveSession();
    });
  }

  void _watchBleStatus() {
    _bleStatusSub = _ble.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _bleStatus = status);

      if (status == BleStatus.ready &&
          _blePermissionsGranted &&
          !_scanning &&
          _sessionId != null) {
        _startScan();
        return;
      }

      if (status != BleStatus.ready && _scanning) {
        _scanSub?.cancel();
        setState(() {
          _scanning = false;
          _scanError = 'Bluetooth state is $status';
        });
      }
    });
  }

  Future<void> _bootstrap() async {
    // Đọc mã sinh viên đã lưu.
    _studentIdentifier = await widget.api.readIdentifier();

    final permsOk = await _ensureBleScanPermissions();
    if (!permsOk) {
      if (mounted) {
        setState(() {
          _blePermissionsGranted = false;
          _scanError = 'Nearby devices permission denied.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions are required for scanning.'),
          ),
        );
      }
      return;
    }

    // Yêu cầu bật Bluetooth nếu cần.
    await _ensureBluetoothEnabled();

    await _loadActiveSession();
    _startScan();
    _startStudentAdvertising();
    _startForegroundService('BLE Attendance — scanning');
  }

  Future<void> _loadActiveSession() async {
    // Ưu tiên lấy buổi học từ máy chủ; mất mạng không làm dừng BLE.
    try {
      final session = await widget.api.getActiveSession();
      if (!mounted) return;
      setState(() {
        _sessionId = session['id'] as String;
        _subject = session['subject'] as String?;
        _finalizationOpen = (session['finalization_open'] as bool?) ?? false;
        _blePermissionsGranted = true;
      });
    } catch (_) {
      // Khi ngoại tuyến, tiếp tục dựa vào beacon BLE của giảng viên.
      // Không xóa mã buổi học nếu BLE đã phát hiện được trước đó.
    }
  }

  Future<void> _startStudentAdvertising() async {
    if (_advertising || _studentIdentifier == null) return;
    try {
      final permsOk = await _ensureBleAdvertisePermissions();
      if (!permsOk) return;

      final idBytes = utf8.encode(_studentIdentifier!);
      final data = AdvertiseData(
        serviceUuid: studentServiceUuid,
        includeDeviceName: false,
        manufacturerId: manufacturerId,
        manufacturerData: Uint8List.fromList(idBytes),
      );
      await _blePeripheral.start(advertiseData: data);
      if (mounted) setState(() => _advertising = true);
    } catch (_) {
      // Một số thiết bị không hỗ trợ phát BLE peripheral.
    }
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    if (_bleStatus != BleStatus.ready) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanError = 'Bluetooth not ready: $_bleStatus';
        });
      }
      _scheduleScanRetry();
      return;
    }
    _scanRetryTimer?.cancel();
    await _scanSub?.cancel();
    setState(() {
      _scanning = true;
      _scanError = null;
    });

    _scanSub = _ble
        .scanForDevices(
          withServices: const [],
          scanMode: ScanMode.lowPower,
          requireLocationServicesEnabled: false,
        )
        .listen(
          (device) {
            // Tìm beacon của giảng viên.
            final payload = _decodeTeacherPayload(device);
            if (payload != null) {
              final rssi = device.rssi;
              _rssiWindow.add(rssi);
              if (_rssiWindow.length > rssiWindowSize) {
                _rssiWindow.removeAt(0);
              }
              final avgRssi = _rssiWindow.isEmpty
                  ? rssi
                  : (_rssiWindow.reduce((a, b) => a + b) / _rssiWindow.length)
                        .round();
              final ok = avgRssi > rssiThreshold;

              // Chống thay đổi trạng thái liên tục do RSSI dao động.
              _updateDebouncedProximity(ok);

              setState(() {
                _latestRssi = avgRssi;
                _sessionId ??= 'ble-detected';
                if (payload['subject'] != null) {
                  _subject = payload['subject'] as String;
                }
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _scanning = false;
                _scanError = 'Scan error: $error';
              });
              _scheduleScanRetry();
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _scanning = false;
                _scanError = 'Scan ended. Retrying...';
              });
              _scheduleScanRetry();
            }
          },
        );
  }

  void _updateDebouncedProximity(bool newValue) {
    final now = DateTime.now();
    if (_rawProximityOk != newValue) {
      _rawProximityOk = newValue;
      _rawProximityChangeAt = now;
    } else if (_rawProximityChangeAt != null &&
        now.difference(_rawProximityChangeAt!) >= proximityDebounceDuration) {
      // Chỉ áp dụng khi trạng thái đã ổn định đủ lâu.
      if (_proximityOk != newValue) {
        setState(() => _proximityOk = newValue);
      }
    }
    // Thiết lập ngay ở lần đo đầu tiên.
    _proximityOk ??= newValue;
  }

  Map<String, dynamic>? _decodeTeacherPayload(DiscoveredDevice device) {
    if (device.manufacturerData.isEmpty) return null;
    try {
      final bytes = device.manufacturerData;
      if (bytes.length < 4) return null;
      final payload = utf8.decode(bytes.sublist(2), allowMalformed: true);
      if (!payload.contains('|')) return null;
      final parts = payload.split('|');
      return {'token': parts[0], 'subject': parts.length > 1 ? parts[1] : null};
    } catch (_) {}
    return null;
  }

  void _scheduleScanRetry() {
    _scanRetryTimer?.cancel();
    _scanRetryTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted || !_blePermissionsGranted || _scanning) return;
      await _startScan();
    });
  }

  Future<void> _finalizeWithBiometric() async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId == 'ble-detected') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need server connection to finalize. Check internet.'),
        ),
      );
      return;
    }
    if (!_finalizationOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher has not opened finalization yet.'),
        ),
      );
      return;
    }

    try {
      final canAuth =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuth) {
        throw Exception(
          'Biometric/passcode auth is not available on this device.',
        );
      }

      final success = await _localAuth.authenticate(
        localizedReason: 'Authenticate to finalize attendance',
        biometricOnly: false,
      );
      if (!success) return;

      final attendance = await widget.api.finalizeAttendance(sessionId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Finalized. Present: ${attendance['is_present']} '
            '| Ratio: ${attendance['presence_ratio']}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _logout() async {
    _scanSub?.cancel();
    _bleStatusSub?.cancel();
    _blePeripheral.stop();
    FlutterForegroundTask.stopService();
    await widget.api.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _proximityOk == null
        ? Colors.grey
        : (_proximityOk! ? Colors.green : Colors.red);
    final statusText = _proximityOk == null
        ? 'Searching for teacher...'
        : (_proximityOk! ? 'In range ✅' : 'Out of range ❌');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tên buổi học.
            if (_subject != null && _subject!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _subject!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No active lecture',
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 16),

            // Trạng thái khoảng cách.
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(statusText, style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),

            // Thông tin chi tiết.
            Text('RSSI: ${_latestRssi ?? '-'}'),
            Text('Scanning: ${_scanning ? 'ON' : 'OFF'}'),
            Text(
              'Advertising ID: ${_advertising ? (_studentIdentifier ?? '-') : 'OFF'}',
            ),
            Text('Bluetooth: $_bleStatus'),
            if (_scanError != null) Text('Status: $_scanError'),
            if (!_blePermissionsGranted)
              const Text(
                'Scanning blocked: enable Nearby devices permission.',
                style: TextStyle(color: Colors.red),
              ),
            Text(
              'Finalization: ${_finalizationOpen ? 'OPEN' : 'WAITING FOR TEACHER'}',
            ),
            const Text(
              'Auto-scanning periodically. No action needed.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // Chốt điểm danh bằng xác thực thiết bị.
            FilledButton.icon(
              onPressed: _finalizationOpen ? _finalizeWithBiometric : null,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Finalize Attendance (Biometric)'),
            ),
            const SizedBox(height: 12),

            // Các thiết lập pin dành riêng cho Android.
            if (Platform.isAndroid) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  const intent = AndroidIntent(
                    action:
                        'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
                  );
                  await intent.launch();
                },
                icon: const Icon(Icons.battery_saver),
                label: const Text('Disable Battery Optimization'),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _openAutoStartSettings,
                icon: const Icon(Icons.settings),
                label: const Text(
                  'Fix Background Restrictions (Xiaomi/Samsung)',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAutoStartSettings() async {
    if (!Platform.isAndroid) return;
    // Thử mở thiết lập tự khởi động của Xiaomi/MIUI.
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: 'com.miui.securitycenter',
        componentName: 'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
      );
      await intent.launch();
      return;
    } catch (_) {}

    // Nếu không hỗ trợ, mở trang thông tin ứng dụng.
    try {
      final intent = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:com.bleattendance.app',
      );
      await intent.launch();
    } catch (_) {}
  }
}

// ===========================================================================
// QUYỀN THIẾT BỊ VÀ HÀM HỖ TRỢ
// ===========================================================================

Future<bool> _ensureBlePermissions() async {
  final bleStatuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
  ].request();

  for (final status in bleStatuses.values) {
    if (!status.isGranted && !status.isLimited) return false;
  }

  await Permission.locationWhenInUse.request();
  return true;
}

Future<bool> _ensureBleAdvertisePermissions() async {
  final bleStatuses = await [
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
  ].request();

  for (final status in bleStatuses.values) {
    if (!status.isGranted && !status.isLimited) return false;
  }
  return true;
}

Future<bool> _ensureBleScanPermissions() async {
  final bleStatuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ].request();

  for (final status in bleStatuses.values) {
    if (!status.isGranted && !status.isLimited) return false;
  }

  await Permission.locationWhenInUse.request();
  return true;
}

Future<void> _ensureBluetoothEnabled() async {
  if (!Platform.isAndroid) return;
  try {
    const intent = AndroidIntent(
      action: 'android.bluetooth.adapter.action.REQUEST_ENABLE',
    );
    await intent.launch();
  } catch (_) {
    // Giao diện sẽ hiển thị trạng thái Bluetooth nếu thao tác thất bại.
  }
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'ble_attendance_fg',
      channelName: 'BLE Attendance',
      channelDescription: 'Keeps BLE scanning/advertising alive',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );
}

Future<void> _startForegroundService(String text) async {
  if (!Platform.isAndroid) return;
  await FlutterForegroundTask.startService(
    notificationTitle: 'BLE Attendance',
    notificationText: text,
  );
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Cannot reach server. Check Server URL and Wi-Fi.';
    }
    if (data is Map && data['detail'] != null) {
      return '${data['detail']} (HTTP ${status ?? '-'})';
    }
    return 'Network/API error (HTTP ${status ?? '-'})';
  }
  return error.toString();
}
