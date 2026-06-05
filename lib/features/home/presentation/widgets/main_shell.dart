import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:stratos_app/core/theme.dart';
import 'package:stratos_app/core/theme_provider.dart';
import 'package:stratos_app/core/widgets/minimalist_widgets.dart';
import 'package:stratos_app/data/dio_client.dart';
import 'package:stratos_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:stratos_app/features/home/application/home_providers.dart';
import 'package:stratos_app/features/home/data/home_models.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final user = profileAsync.value;
    final isWide = MediaQuery.of(context).size.width >= 960;
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final navItems = _navItems(user);
    final themeMode = ref.watch(themeModeProvider);
    final themeIcon = _themeIcon(themeMode);

    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
              title: const Text(
                'Stratos LMS',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              actions: [
                IconButton(
                  icon: Icon(themeIcon),
                  onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                ),
              ],
            ),
      drawer: isWide
          ? null
          : Drawer(
              child: _ShellDrawer(
                user: user,
                navItems: navItems,
                currentLocation: currentLocation,
                onNavigate: (routeName) => context.goNamed(routeName),
                onLogout: () => ref.read(authControllerProvider.notifier).logout(),
                onToggleTheme: () => ref.read(themeModeProvider.notifier).toggle(),
                themeIcon: themeIcon,
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              _ShellRail(
                user: user,
                navItems: navItems,
                currentLocation: currentLocation,
                onNavigate: (routeName) => context.goNamed(routeName),
                onLogout: () => ref.read(authControllerProvider.notifier).logout(),
                onToggleTheme: () => ref.read(themeModeProvider.notifier).toggle(),
                themeIcon: themeIcon,
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  List<_NavItem> _navItems(AppUser? user) {
    final isInstructor = user?.role == 'instructor' || user?.role == 'admin';
    final isAdmin = user?.role == 'admin';

    return [
      _NavItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        routeName: 'home',
        matches: const ['/'],
      ),
      _NavItem(
        icon: Icons.school_outlined,
        label: isInstructor ? 'My Academy' : 'Academy',
        routeName: 'courses',
        matches: const ['/courses'],
      ),
      _NavItem(
        icon: Icons.forum_outlined,
        label: 'Messages',
        routeName: 'messages',
        matches: const ['/messages'],
      ),
      _NavItem(
        icon: Icons.campaign_outlined,
        label: 'Announcements',
        routeName: 'announcements',
        matches: const ['/announcements'],
      ),
      if (isInstructor)
        _NavItem(
          icon: Icons.analytics_outlined,
          label: 'Reports',
          routeName: 'reports',
          matches: const ['/reports'],
        ),
      if (isAdmin)
        _NavItem(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Admin',
          routeName: 'admin',
          matches: const ['/admin'],
        ),
      _NavItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        routeName: 'settings',
        matches: const ['/settings'],
      ),
    ];
  }
}

class _ShellRail extends ConsumerWidget {
  const _ShellRail({
    required this.user,
    required this.navItems,
    required this.currentLocation,
    required this.onNavigate,
    required this.onLogout,
    required this.onToggleTheme,
    required this.themeIcon,
  });

  final AppUser? user;
  final List<_NavItem> navItems;
  final String currentLocation;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final IconData themeIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isInstructor = user?.role == 'instructor' || user?.role == 'admin';
    final accentColor = isInstructor ? AppColors.primary : AppColors.secondary;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: theme.colorScheme.primary, size: 32),
                const SizedBox(width: 14),
                Text(
                  'Stratos', 
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = _matchesLocation(currentLocation, item.matches);
                return Stack(
                  children: [
                    ListTile(
                      leading: Icon(
                        item.icon, 
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                      onTap: () => onNavigate(item.routeName),
                    ),
                    if (isSelected)
                      Positioned(
                        left: 0,
                        top: 12,
                        bottom: 12,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _ShellProfileCard(user: user, onLogout: onLogout),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ShellDrawer extends ConsumerWidget {
  const _ShellDrawer({
    required this.user,
    required this.navItems,
    required this.currentLocation,
    required this.onNavigate,
    required this.onLogout,
    required this.onToggleTheme,
    required this.themeIcon,
  });

  final AppUser? user;
  final List<_NavItem> navItems;
  final String currentLocation;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final IconData themeIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isInstructor = user?.role == 'instructor' || user?.role == 'admin';
    final accentColor = isInstructor ? AppColors.primary : AppColors.secondary;
    final serverBaseUrl = ref.watch(serverBaseUrlProvider);

    return Container(
      color: theme.colorScheme.surfaceContainer,
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: accentColor.withValues(alpha: 0.14),
                      backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                          ? NetworkImage(user!.avatarUrl!.startsWith('http') 
                              ? user!.avatarUrl! 
                              : '$serverBaseUrl${user!.avatarUrl!.startsWith('/') ? '' : '/'}${user!.avatarUrl!}')
                          : null,
                      child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                          ? Text(
                              _safeInitial(user),
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Flexible(child: Text(user?.displayName ?? 'User', style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis)),
                    Text(user?.role.toUpperCase() ?? 'STUDENT', style: theme.textTheme.labelMedium),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    onPressed: onToggleTheme,
                    icon: Icon(themeIcon),
                    tooltip: 'Toggle theme',
                  ),
                ),
              ],
            ),
          ),
          for (final item in navItems)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              selected: _matchesLocation(currentLocation, item.matches),
              selectedTileColor: accentColor.withValues(alpha: 0.1),
              onTap: () {
                Navigator.pop(context);
                onNavigate(item.routeName);
              },
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _ShellProfileCard(
              user: user,
              onLogout: () {
                Navigator.pop(context);
                onLogout();
              },
              logoutLabel: 'Sign out',
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellProfileCard extends ConsumerWidget {
  const _ShellProfileCard({
    required this.user,
    required this.onLogout,
    this.logoutLabel = 'Logout',
  });

  final AppUser? user;
  final VoidCallback onLogout;
  final String logoutLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = user?.role == 'instructor' || user?.role == 'admin' ? AppColors.primary : AppColors.secondary;
    final serverBaseUrl = ref.watch(serverBaseUrlProvider);

    return MinimalContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      showBorder: false,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                ? NetworkImage(user!.avatarUrl!.startsWith('http') 
                    ? user!.avatarUrl! 
                    : '$serverBaseUrl${user!.avatarUrl!.startsWith('/') ? '' : '/'}${user!.avatarUrl!}')
                : null,
            child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                ? Text(
                    _safeInitial(user),
                    style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    user?.displayName ?? 'User', 
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 18),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.routeName,
    required this.matches,
  });

  final IconData icon;
  final String label;
  final String routeName;
  final List<String> matches;
}

String _safeInitial(AppUser? user) {
  final name = user?.displayName.trim();
  if (name == null || name.isEmpty) return 'U';
  return name[0].toUpperCase();
}

IconData _themeIcon(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => Icons.brightness_auto,
    ThemeMode.dark => Icons.dark_mode,
    ThemeMode.light => Icons.light_mode,
  };
}

bool _matchesLocation(String location, List<String> matches) {
  return matches.any((pattern) {
    if (pattern == '/') return location == '/';
    return location == pattern || location.startsWith('$pattern/');
  });
}
