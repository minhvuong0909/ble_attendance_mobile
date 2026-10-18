import 'package:flutter/material.dart';

import '../../models/app_role.dart';
import '../notifications/notifications_screen.dart';
import '../student/student_classes_screen.dart';
import '../teacher/teacher_classes_screen.dart';
import '../student/student_home_screen.dart';
import '../student/student_leave_screen.dart';
import 'placeholder_tab.dart';
import 'shell_tabs.dart';

/// Trang tương ứng với tab thứ [index] của vai trò [role].
Widget pageFor(AppRole role, int index) {
  final tab = tabsFor(role)[index];
  if (tab.path.endsWith('/notifications')) return const NotificationsScreen();
  if (role == AppRole.teacher && index == 0) {
    return const TeacherClassesScreen();
  }
  if (role == AppRole.student) {
    switch (index) {
      case 0:
        return const StudentHomeScreen();
      case 1:
        return const StudentClassesScreen();
      case 2:
        return const StudentLeaveScreen();
    }
  }
  return PlaceholderTab(title: tab.label, icon: tab.icon);
}
