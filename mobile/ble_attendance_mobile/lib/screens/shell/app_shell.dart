import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_role.dart';
import '../../providers/auth_controller.dart';
import 'shell_tabs.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell, required this.role});

  final StatefulNavigationShell navigationShell;
  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = tabsFor(role);
    final index = navigationShell.currentIndex;
    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[index].label),
        actions: const [ProfileMenu()],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            navigationShell.goBranch(i, initialLocation: i == index),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
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
    final initial = (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : '?';
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
              Text(user?.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
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
