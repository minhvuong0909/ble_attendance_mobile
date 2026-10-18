import 'package:flutter/material.dart';

import '../models/attendance_status.dart';
import '../models/leave_request.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon == null ? null : Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFC62828);
const _orange = Color(0xFFEF6C00);

Widget attendanceChip(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => StatusChip(
    label: status.label,
    color: _green,
    icon: Icons.check_circle,
  ),
  AttendanceStatus.absent => StatusChip(
    label: status.label,
    color: _red,
    icon: Icons.cancel,
  ),
  AttendanceStatus.excused => StatusChip(
    label: status.label,
    color: _orange,
    icon: Icons.event_available,
  ),
};

Widget leaveChip(LeaveStatus status) => switch (status) {
  LeaveStatus.pending => StatusChip(
    label: status.label,
    color: _orange,
    icon: Icons.hourglass_top,
  ),
  LeaveStatus.approved => StatusChip(
    label: status.label,
    color: _green,
    icon: Icons.check_circle,
  ),
  LeaveStatus.rejected => StatusChip(
    label: status.label,
    color: _red,
    icon: Icons.cancel,
  ),
};
