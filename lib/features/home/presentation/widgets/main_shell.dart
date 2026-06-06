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
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final user = profileAsync.value;
    final stats = ref.watch(statsProvider).value;
    final unreadMessages = stats?.unreadMessages ?? 0;

    final isWide = MediaQuery.of(context).size.width >= 960;
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final navItems = _navItems(user);
    final themeMode = ref.watch(themeModeProvider);
    final themeIcon = _themeIcon(themeMode);
    final selectedIndex = _selectedIndex(currentLocation, navItems);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Mobile app bar
      appBar: isWide
          ? null
          : AppBar(
              title: Text(
                selectedIndex >= 0 ? navItems[selectedIndex].label : 'Stratos',
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              actions: [
                IconButton(
                  icon: Icon(themeIcon),
                  onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                ),
                _MobileAvatarButton(user: user),
                const SizedBox(width: 8),
              ],
            ),

      // Mobile bottom nav
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (i) => context.goNamed(navItems[i].routeName),
              destinations: navItems
                  .map((item) => NavigationDestination(
                        icon: item.routeName == 'messages' && unreadMessages > 0
                            ? Badge(
                                label: Text('$unreadMessages'),
                                child: Icon(item.icon),
                              )
                            : Icon(item.icon),
                        label: item.label,
                      ))
                  .toList(),
            ),

      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              _ShellRail(
                user: user,
                navItems: navItems,
                currentLocation: currentLocation,
                unreadMessages: unreadMessages,
                onNavigate: (routeName) => context.goNamed(routeName),
                onLogout: () => ref.read(authControllerProvider.notifier).logout(),
                onToggleTheme: () => ref.read(themeModeProvider.notifier).toggle(),
                themeIcon: themeIcon,
              ),
            Expanded(
              child: Column(
                children: [
                  if (isWide) const _TopAppBar(),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_NavItem> _navItems(AppUser? user) {
    final isInstructor = user?.role == 'instructor' || user?.role == 'admin';
    final isAdmin = user?.role == 'admin';

    return [
      const _NavItem(icon: Icons.dashboard_outlined, label: 'Home', routeName: 'home', matches: ['/']),
      _NavItem(icon: Icons.school_outlined, label: isInstructor ? 'Academy' : 'Courses', routeName: 'courses', matches: const ['/courses']),
      const _NavItem(icon: Icons.forum_outlined, label: 'Messages', routeName: 'messages', matches: ['/messages']),
      const _NavItem(icon: Icons.campaign_outlined, label: 'Announce', routeName: 'announcements', matches: ['/announcements']),
      if (isInstructor)
        const _NavItem(icon: Icons.analytics_outlined, label: 'Reports', routeName: 'reports', matches: ['/reports']),
      if (isAdmin)
        const _NavItem(icon: Icons.admin_panel_settings_outlined, label: 'Admin', routeName: 'admin', matches: ['/admin']),
      const _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', routeName: 'settings', matches: ['/settings']),
    ];
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 60, // Reduced height since it's empty
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [],
      ),
    );
  }
}

// Small avatar in mobile AppBar — taps to profile/settings
class _MobileAvatarButton extends ConsumerWidget {
  const _MobileAvatarButton({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isInstructor = user?.role == 'instructor' || user?.role == 'admin';
    final accentColor = isInstructor ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final serverBaseUrl = ref.watch(serverBaseUrlProvider);

    return GestureDetector(
      onTap: () => context.goNamed('settings'),
      child: SafeAvatar(
        imageUrl: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
            ? (user!.avatarUrl!.startsWith('http')
                ? user!.avatarUrl!
                : '$serverBaseUrl${user!.avatarUrl!.startsWith('/') ? '' : '/'}${user!.avatarUrl!}')
            : null,
        radius: 16,
        backgroundColor: accentColor.withValues(alpha: 0.15),
        fallbackText: _safeInitial(user),
        fallbackTextColor: accentColor,
        fontSize: 11,
      ),
    );
  }
}

class _ShellRail extends ConsumerWidget {
  const _ShellRail({
    required this.user,
    required this.navItems,
    required this.currentLocation,
    required this.unreadMessages,
    required this.onNavigate,
    required this.onLogout,
    required this.onToggleTheme,
    required this.themeIcon,
  });

  final AppUser? user;
  final List<_NavItem> navItems;
  final String currentLocation;
  final int unreadMessages;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final VoidCallback onToggleTheme;
  final IconData themeIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isInstructor = user?.role == 'instructor' || user?.role == 'admin';
    final accentColor = isInstructor ? theme.colorScheme.primary : theme.colorScheme.secondary;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: isDark
            ? Border(right: BorderSide(color: AppColors.darkBorder, width: 1))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                ),
              ],
      ),
      child: Column(
        children: [
          // Logo / brand
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_stories_rounded, color: theme.colorScheme.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Stratos',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: theme.colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_themeIcon(ref.watch(themeModeProvider)),
                      color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onPressed: onToggleTheme,
                  tooltip: 'Toggle theme',
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = _matchesLocation(currentLocation, item.matches);
                final bool isMessages = item.routeName == 'messages';

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onNavigate(item.routeName),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          if (isMessages && unreadMessages > 0)
                            Badge(
                              label: Text('$unreadMessages'),
                              child: Icon(
                                item.icon,
                                color: isSelected ? accentColor : theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            )
                          else
                            Icon(
                              item.icon,
                              color: isSelected ? accentColor : theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          const SizedBox(width: 12),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? accentColor : theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          if (isSelected) ...[
                            const Spacer(),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Profile card
          Padding(
            padding: const EdgeInsets.all(16),
            child: _RailProfileCard(user: user, onLogout: onLogout),
          ),
        ],
      ),
    );
  }
}

class _RailProfileCard extends ConsumerWidget {
  const _RailProfileCard({required this.user, required this.onLogout});

  final AppUser? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isInstructor = user?.role == 'instructor' || user?.role == 'admin';
    final accentColor = isInstructor ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final serverBaseUrl = ref.watch(serverBaseUrlProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: AppColors.darkBorder, width: 1)
            : null,
      ),
      child: Row(
        children: [
          SafeAvatar(
            imageUrl: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                ? (user!.avatarUrl!.startsWith('http')
                    ? user!.avatarUrl!
                    : '$serverBaseUrl${user!.avatarUrl!.startsWith('/') ? '' : '/'}${user!.avatarUrl!}')
                : null,
            radius: 18,
            backgroundColor: accentColor.withValues(alpha: 0.15),
            fallbackText: _safeInitial(user),
            fallbackTextColor: accentColor,
            fontSize: 12,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.displayName ?? 'User',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user?.role.toUpperCase() ?? 'STUDENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            tooltip: 'Sign out',
            onPressed: onLogout,
          ),
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

int _selectedIndex(String location, List<_NavItem> items) {
  for (int i = 0; i < items.length; i++) {
    if (_matchesLocation(location, items[i].matches)) return i;
  }
  return 0;
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
