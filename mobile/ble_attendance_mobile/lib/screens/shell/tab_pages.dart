import 'package:flutter/material.dart';

import '../../models/app_role.dart';
import '../notifications/notifications_screen.dart';
import 'placeholder_tab.dart';
import 'shell_tabs.dart';

/// Trang tương ứng với tab thứ [index] của vai trò [role].
Widget pageFor(AppRole role, int index) {
  final tab = tabsFor(role)[index];
  if (tab.path.endsWith('/notifications')) return const NotificationsScreen();
  return PlaceholderTab(title: tab.label, icon: tab.icon);
}
