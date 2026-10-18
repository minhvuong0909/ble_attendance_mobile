import 'package:flutter/material.dart';

import '../../models/app_role.dart';

class ShellTab {
  const ShellTab(this.label, this.path, this.icon, this.selectedIcon);

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

List<ShellTab> tabsFor(AppRole role) => switch (role) {
  AppRole.student => const [
    ShellTab('Trang chủ', '/student', Icons.home_outlined, Icons.home),
    ShellTab(
      'Lớp của tôi',
      '/student/classes',
      Icons.school_outlined,
      Icons.school,
    ),
    ShellTab(
      'Xin phép',
      '/student/leave',
      Icons.event_busy_outlined,
      Icons.event_busy,
    ),
    ShellTab(
      'Thông báo',
      '/student/notifications',
      Icons.notifications_outlined,
      Icons.notifications,
    ),
  ],
  AppRole.teacher => const [
    ShellTab('Lớp học', '/teacher', Icons.class_outlined, Icons.class_),
    ShellTab(
      'Buổi trực tiếp',
      '/teacher/live',
      Icons.sensors_outlined,
      Icons.sensors,
    ),
    ShellTab(
      'Xin phép',
      '/teacher/leave',
      Icons.event_busy_outlined,
      Icons.event_busy,
    ),
    ShellTab(
      'Thông báo',
      '/teacher/notifications',
      Icons.notifications_outlined,
      Icons.notifications,
    ),
  ],
  AppRole.admin => const [
    ShellTab('Môn học', '/admin', Icons.menu_book_outlined, Icons.menu_book),
    ShellTab('Lớp học', '/admin/classes', Icons.class_outlined, Icons.class_),
    ShellTab(
      'Giảng viên',
      '/admin/teachers',
      Icons.badge_outlined,
      Icons.badge,
    ),
    ShellTab(
      'Sinh viên',
      '/admin/students',
      Icons.groups_outlined,
      Icons.groups,
    ),
  ],
};
