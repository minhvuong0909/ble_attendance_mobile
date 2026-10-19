import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_role.dart';
import '../../providers/auth_controller.dart';
import '../../providers/notifications_provider.dart';
import 'shell_tabs.dart';
import 'tab_pages.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.role,
  });

  final StatefulNavigationShell navigationShell;
  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = tabsFor(role);
    final index = navigationShell.currentIndex;
    // Có thông báo mới thường đi kèm dữ liệu mới (đơn xin phép, buổi học, kết quả...): làm mới các tab.
    ref.listen(unreadCountProvider, (previous, next) {
      if (next > (previous ?? 0)) refreshAllTabs(ref, role);
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[index].label),
        actions: const [ProfileMenu()],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          refreshTab(ref, role, i);
          navigationShell.goBranch(i, initialLocation: i == index);
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: _TabIcon(tab: tab, selected: false),
              selectedIcon: _TabIcon(tab: tab, selected: true),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final initial = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName[0].toUpperCase()
        : '?';
    return PopupMenuButton<String>(
      key: const Key('profile-menu'),
      tooltip: 'Tài khoản',
      icon: CircleAvatar(radius: 16, child: Text(initial)),
      onSelected: (value) {
        switch (value) {
          case 'password':
            context.push('/change-password');
          case 'settings':
            context.push('/settings');
          case 'logout':
            ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.fullName ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${user?.role.label ?? ''} · ${user?.loginId ?? ''}'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'password', child: Text('Đổi mật khẩu')),
        const PopupMenuItem(value: 'settings', child: Text('Cài đặt máy chủ')),
        const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
      ],
    );
  }
}

/// Biểu tượng tab; tab thông báo có badge số chưa đọc.
class _TabIcon extends ConsumerWidget {
  const _TabIcon({required this.tab, required this.selected});

  final ShellTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = Icon(selected ? tab.selectedIcon : tab.icon);
    if (!tab.path.endsWith('/notifications')) return icon;
    final count = ref.watch(unreadCountProvider);
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }
}
