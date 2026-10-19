import 'package:flutter/material.dart';

import '../ble/ble_gateway.dart';
import '../providers/student_beacon.dart';
import '../providers/teacher_beacon.dart';
import 'warning_banner.dart';

String? _problemText(BleReadiness? problem) => switch (problem) {
  null => null,
  BleReadiness.ready => null,
  BleReadiness.permissionDenied =>
    'Chưa được cấp quyền Bluetooth/Vị trí. Hãy cấp quyền rồi thử lại '
        '(Android 11 trở xuống cần bật cả Vị trí).',
  BleReadiness.bluetoothOff =>
    'Bluetooth đang tắt. Hãy bật Bluetooth rồi thử lại.',
  BleReadiness.unsupported =>
    'Thiết bị không hỗ trợ phát BLE nên không thể điểm danh.',
};

const _batteryTip =
    'Nếu máy tắt BLE khi khóa màn hình, hãy tắt tối ưu pin cho app trong Cài đặt.';

class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({required this.problem, required this.onRetry});

  final BleReadiness problem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WarningBanner(_problemText(problem)!),
        const SizedBox(height: 8),
        if (problem != BleReadiness.unsupported)
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
      ],
    );
  }
}

/// Trạng thái BLE của sinh viên: gần/xa lớp, hoặc lý do chưa chạy.
class StudentBleCard extends StatelessWidget {
  const StudentBleCard({super.key, required this.state, required this.onRetry});

  final StudentBeaconState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.problem != null) {
      return _ProblemBanner(problem: state.problem!, onRetry: onRetry);
    }
    final (icon, color, text) = switch (state.proximity) {
      Proximity.near => (
        Icons.check_circle,
        const Color(0xFF2E7D32),
        'Bạn đang ở trong phạm vi lớp học',
      ),
      Proximity.far => (
        Icons.signal_cellular_connected_no_internet_0_bar,
        const Color(0xFFEF6C00),
        'Bạn đang ở xa lớp học. Hãy lại gần giảng viên.',
      ),
      Proximity.unknown => (
        Icons.bluetooth_searching,
        theme.colorScheme.outline,
        state.active
            ? 'Đang tìm tín hiệu của giảng viên…'
            : 'Đang bật Bluetooth…',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, key: const Key('student-ble-text'))),
          ],
        ),
        if (state.scanError) ...[
          const SizedBox(height: 4),
          Text(
            'Quét BLE gặp lỗi, đang thử lại.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 4),
        Text(_batteryTip, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Trạng thái BLE của giảng viên: số sinh viên đã thấy và tình trạng gửi.
class TeacherBleCard extends StatelessWidget {
  const TeacherBleCard({super.key, required this.state, required this.onRetry});

  final TeacherBeaconState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.problem != null) {
      return _ProblemBanner(problem: state.problem!, onRetry: onRetry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bluetooth_audio, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.active ? 'Đang phát và quét BLE' : 'Đang bật Bluetooth…',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Đã thấy ${state.studentsSeen} sinh viên · chờ gửi ${state.pending} · '
          'đã gửi ${state.sent}',
          key: const Key('teacher-ble-counts'),
        ),
        if (state.sendError) ...[
          const SizedBox(height: 8),
          const WarningBanner(
            'Chưa gửi được dữ liệu lên máy chủ, sẽ tự thử lại. Giữ app mở.',
          ),
        ],
        if (state.scanError) ...[
          const SizedBox(height: 4),
          Text(
            'Quét BLE gặp lỗi, đang thử lại.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 4),
        Text(_batteryTip, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
