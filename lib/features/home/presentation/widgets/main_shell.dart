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
import '../../../../core/utils/locale_provider.dart';

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
    final navItems = _navItems(context, user);
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

  List<_NavItem> _navItems(BuildContext context, AppUser? user) {
    final l10n = AppLocalizations.of(context);
    final isInstructor = user?.role == 'instructor' || user?.role == 'admin';
    final isAdmin = user?.role == 'admin';

    return [
      _NavItem(icon: Icons.dashboard_outlined, label: l10n.translate('home'), routeName: 'home', matches: const ['/']),
      _NavItem(icon: Icons.school_outlined, label: isInstructor ? l10n.translate('academy') : l10n.translate('courses'), routeName: 'courses', matches: const ['/courses']),
      _NavItem(icon: Icons.forum_outlined, label: l10n.translate('messages'), routeName: 'messages', matches: const ['/messages']),
      _NavItem(icon: Icons.campaign_outlined, label: l10n.translate('announce'), routeName: 'announcements', matches: const ['/announcements']),
      if (isInstructor)
        _NavItem(icon: Icons.analytics_outlined, label: l10n.translate('reports'), routeName: 'reports', matches: const ['/reports']),
      if (isAdmin)
        _NavItem(icon: Icons.admin_panel_settings_outlined, label: l10n.translate('admin'), routeName: 'admin', matches: const ['/admin']),
      _NavItem(icon: Icons.person_outline_rounded, label: l10n.translate('settings'), routeName: 'settings', matches: const ['/settings']),
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
    const accentColor = AppColors.primary;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo / brand - Clean and simple
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.black, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Class IQ',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Nav items - Minimalist list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = _matchesLocation(currentLocation, item.matches);
                final bool isMessages = item.routeName == 'messages';

                return InkWell(
                  onTap: () => onNavigate(item.routeName),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        if (isMessages && unreadMessages > 0)
                          Badge(
                            label: Text('$unreadMessages'),
                            backgroundColor: accentColor,
                            textColor: Colors.black,
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
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom actions & Profile
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
    final accentColor = AppColors.primary;
    final serverBaseUrl = ref.watch(serverBaseUrlProvider);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        children: [
          SafeAvatar(
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.displayName ?? 'User',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user?.role == 'instructor' ? l10n.translate('instructor') : l10n.translate('student'),
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 18),
            onPressed: onLogout,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: theme.colorScheme.onSurfaceVariant,
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
