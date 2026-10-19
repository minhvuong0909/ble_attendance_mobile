import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../models/app_role.dart';
import '../../providers/admin_providers.dart';
import '../../providers/leave_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/teacher_providers.dart';
import '../admin/admin_classes_screen.dart';
import '../admin/admin_courses_screen.dart';
import '../admin/admin_teachers_screen.dart';
import '../notifications/notifications_screen.dart';
import '../student/student_classes_screen.dart';
import '../teacher/teacher_classes_screen.dart';
import '../teacher/teacher_leave_screen.dart';
import '../teacher/teacher_live_screen.dart';
import '../student/student_home_screen.dart';
import '../student/student_leave_screen.dart';
import 'placeholder_tab.dart';
import 'shell_tabs.dart';

/// Trang tương ứng với tab thứ [index] của vai trò [role].
Widget pageFor(AppRole role, int index) {
  final tab = tabsFor(role)[index];
  if (tab.path.endsWith('/notifications')) return const NotificationsScreen();
  if (role == AppRole.teacher) {
    if (index == 0) return const TeacherClassesScreen();
    if (index == 1) return const TeacherLiveScreen();
    if (index == 2) return const TeacherLeaveScreen();
  }
  if (role == AppRole.admin) {
    if (index == 0) return const AdminCoursesScreen();
    if (index == 1) return const AdminClassesScreen();
    if (index == 2) return const AdminTeachersScreen();
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

/// Làm mới dữ liệu của tab [index] (gọi khi người dùng chọn tab, vì các tab được giữ sống trong IndexedStack).
void refreshTab(WidgetRef ref, AppRole role, int index) {
  for (final provider in _providersFor(role, index)) {
    ref.invalidate(provider);
  }
}

/// Làm mới dữ liệu của mọi tab (gọi khi có thông báo mới, thường kèm thay đổi dữ liệu).
void refreshAllTabs(WidgetRef ref, AppRole role) {
  for (var i = 0; i < tabsFor(role).length; i++) {
    refreshTab(ref, role, i);
  }
}

List<ProviderOrFamily> _providersFor(AppRole role, int index) {
  switch (role) {
    case AppRole.student:
      return switch (index) {
        0 => [activeSessionProvider],
        1 => [classStatsProvider],
        2 => [myLeaveProvider],
        3 => [notificationsProvider],
        _ => const [],
      };
    case AppRole.teacher:
      return switch (index) {
        0 => [myClassListProvider],
        1 => [activeSessionProvider],
        2 => [teacherLeaveProvider],
        3 => [notificationsProvider],
        _ => const [],
      };
    case AppRole.admin:
      return switch (index) {
        0 => [adminCoursesProvider],
        1 => [adminClassesProvider],
        2 => [adminTeachersProvider],
        _ => const [],
      };
  }
}
