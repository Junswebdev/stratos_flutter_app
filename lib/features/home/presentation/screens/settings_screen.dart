import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:stratos_app/data/dio_client.dart';
import 'package:stratos_app/core/theme.dart';
import 'package:stratos_app/core/theme_provider.dart';
import 'package:stratos_app/core/widgets/minimalist_widgets.dart';
import 'package:stratos_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:stratos_app/features/home/application/app_settings_provider.dart';
import 'package:stratos_app/features/home/application/home_providers.dart';
import 'package:stratos_app/features/home/data/home_models.dart';
import 'package:stratos_app/core/utils/locale_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _appVersion = '1.0.0+1';
  final _profileFormKey = GlobalKey<FormState>();
  TextEditingController? _nameController;
  TextEditingController? _emailController;
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  bool _isEditingProfile = false;
  bool _savingProfile = false;
  bool _savingAvatar = false;

  @override
  void dispose() {
    _nameController?.dispose();
    _emailController?.dispose();
    super.dispose();
  }

  void _syncControllers(AppUser? user) {
    if (user == null) return;
    _nameController ??= TextEditingController();
    _emailController ??= TextEditingController();

    if (!_isEditingProfile) {
      _nameController!.text = user.displayName;
      _emailController!.text = user.email;
    }
  }

  String _displayInitial(AppUser? user) {
    final name = user?.displayName.trim();
    if (name == null || name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'Dark',
      ThemeMode.light => 'Light',
      ThemeMode.system => 'System',
    };
  }

  Future<void> _saveProfile(AppUser? user) async {
    if (user == null || _nameController == null || _emailController == null) return;
    final form = _profileFormKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController!.text.trim();
    final email = _emailController!.text.trim();

    if (name == user.displayName && email == user.email) {
      setState(() => _isEditingProfile = false);
      return;
    }

    setState(() => _savingProfile = true);
    final authNotifier = ref.read(authControllerProvider.notifier);

    final success = await authNotifier.updateProfile(
      fullName: name,
      email: email,
    );
    if (!mounted) return;
    setState(() => _savingProfile = false);

    if (success) {
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
      setState(() => _isEditingProfile = false);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    }
  }

  Future<void> _pickAvatar(AppUser? user) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _avatarBytes = file.bytes;
      _avatarFileName = file.name;
      _isEditingProfile = true;
    });

    if (user == null) return;
    setState(() => _savingAvatar = true);
    final authNotifier = ref.read(authControllerProvider.notifier);

    final success = await authNotifier.updateAvatar(
      imageBytes: file.bytes!,
      fileName: file.name,
    );
    if (!mounted) return;
    setState(() => _savingAvatar = false);

    if (success) {
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated')),
        );
      }
      setState(() {
        _avatarBytes = null;
        _avatarFileName = null;
      });
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update avatar')),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocalState) {
              return AlertDialog(
                title: const Text('Change Password'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: newPasswordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          suffixIcon: IconButton(
                            onPressed: () => setLocalState(() => obscurePassword = !obscurePassword),
                            icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Confirm password'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) return;

      final newPassword = newPasswordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();
      if (newPassword.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a new password')),
          );
        }
        return;
      }
      if (newPassword != confirmPassword) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match')),
          );
        }
        return;
      }

      final authNotifier = ref.read(authControllerProvider.notifier);
      final success = await authNotifier.updateProfile(
        password: newPassword,
      );

      if (!mounted) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Password updated' : 'Failed to update password'),
          ),
        );
      }
      if (success) {
        ref.invalidate(profileProvider);
      }
    } finally {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  Future<void> _resetPreferences() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset preferences?'),
        content: const Text('This will restore theme, notifications, language, and biometric settings to defaults.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    
    await settingsNotifier.resetToDefaults();
    themeNotifier.setSystem();

    if (!mounted) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences restored to defaults')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: Text(l10n.translate('settings')),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.translate('personal_profile')),
              Tab(text: l10n.translate('system_settings')),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ),
        body: profileAsync.when(
          data: (user) {
            _syncControllers(user);
            final appSettings = ref.watch(appSettingsProvider);
            final themeMode = ref.watch(themeModeProvider);
            final baseUrl = ref.watch(apiBaseUrlProvider);

            return TabBarView(
              children: [
                // Profile Tab
                _buildProfileTab(user, baseUrl),
                // System Tab
                _buildSystemTab(themeMode, appSettings, baseUrl),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildProfileTab(AppUser? user, String baseUrl) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final contentWidth = constraints.maxWidth > 900 ? 700.0 : constraints.maxWidth;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(user, ref.watch(themeModeProvider), ref.watch(appSettingsProvider), baseUrl, isCompact),
                  const SizedBox(height: 24),
                  _buildSectionTitle(l10n.translate('profile_information')),
                  const SizedBox(height: 12),
                  _buildProfileCard(user, baseUrl, isCompact),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Account Security'),
                  const SizedBox(height: 12),
                  _buildSecurityCard(ref.watch(appSettingsProvider)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemTab(ThemeMode themeMode, AppSettings settings, String baseUrl) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth > 900 ? 700.0 : constraints.maxWidth;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(l10n.translate('interface_appearance')),
                  const SizedBox(height: 12),
                  _buildAppearanceCard(themeMode, settings),
                  const SizedBox(height: 24),
                  _buildSectionTitle(l10n.translate('platform_diagnostics')),
                  const SizedBox(height: 12),
                  _buildSystemCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(l10n.translate('maintenance_session')),
                  const SizedBox(height: 12),
                  _buildMaintenanceCard(),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Class IQ v1.0.0+1',
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(AppUser? user, ThemeMode themeMode, AppSettings settings, String baseUrl, bool isCompact) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                foregroundImage: _avatarBytes != null
                    ? MemoryImage(_avatarBytes!)
                    : _networkAvatarImage(user, baseUrl),
                child: _avatarBytes == null
                    ? Text(
                        _displayInitial(user),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              if (!isCompact) ...[
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'User', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (isCompact) ...[
            const SizedBox(height: 16),
            Text(user?.displayName ?? 'User', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(user?.email ?? '', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: user?.role.toUpperCase() ?? 'STUDENT', color: AppColors.primary),
              _StatusChip(label: 'Theme: ${_themeLabel(themeMode)}', color: AppColors.textSecondary),
              _StatusChip(
                label: settings.pushNotifications ? 'Live Sync active' : 'Polling mode',
                color: settings.pushNotifications ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildProfileCard(AppUser? user, String baseUrl, bool isCompact) {
    final isEditing = _isEditingProfile;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _savingAvatar ? null : () => _pickAvatar(user),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        foregroundImage: _avatarBytes != null
                            ? MemoryImage(_avatarBytes!)
                            : _networkAvatarImage(user, baseUrl),
                        child: Text(_displayInitial(user), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded, size: 8, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Public Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                if (!isCompact && !isEditing)
                  TextButton.icon(
                    onPressed: () => setState(() => _isEditingProfile = true),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              enabled: isEditing,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              enabled: isEditing,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            if (isEditing) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _syncControllers(user);
                        setState(() => _isEditingProfile = false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _saveProfile(user),
                      child: _savingProfile ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text(l10n.translate('save_changes')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(ThemeMode themeMode, AppSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.light_mode_outlined,
            title: l10n.translate('appearance'),
            subtitle: _themeLabel(themeMode),
            onTap: () => _showThemePicker(themeMode),
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.notifications_none_rounded,
            title: l10n.translate('push_notifications'),
            subtitle: settings.pushNotifications ? 'Enabled' : 'Disabled',
            trailing: Switch.adaptive(
              value: settings.pushNotifications,
              activeColor: AppColors.primary,
              onChanged: (v) => ref.read(appSettingsProvider.notifier).setNotifications(v),
            ),
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.language_rounded,
            title: l10n.translate('language'),
            subtitle: locale.languageCode == 'en' ? 'English (US)' : 'Filipino (PH)',
            onTap: () => ref.read(localeProvider.notifier).toggleLanguage(),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(AppSettings settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Last updated 3 months ago',
            onTap: _showChangePasswordDialog,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.fingerprint_rounded,
            title: 'Biometric Access',
            subtitle: 'Fingerprint / Face ID',
            trailing: Switch.adaptive(
              value: settings.biometricAuth,
              activeColor: AppColors.primary,
              onChanged: (v) => ref.read(appSettingsProvider.notifier).setBiometric(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.refresh_rounded,
            title: l10n.translate('reset_preferences'),
            subtitle: 'Restore system defaults',
            onTap: _resetPreferences,
          ),
          const Divider(height: 1),
          _buildSettingsTile(
            icon: Icons.logout_rounded,
            title: l10n.translate('sign_out'),
            titleColor: Colors.red,
            subtitle: 'Securely end session',
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseUrl = ref.watch(apiBaseUrlProvider);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          _InfoRow(label: l10n.translate('version'), value: _appVersion),
          const SizedBox(height: 12),
          _InfoRow(label: l10n.translate('environment'), value: baseUrl.contains('localhost') ? 'Development' : 'Production'),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: titleColor ?? AppColors.primary),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: titleColor)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
    );
  }

  void _showThemePicker(ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: const Text('System'), leading: const Icon(Icons.brightness_auto), onTap: () { ref.read(themeModeProvider.notifier).setSystem(); Navigator.pop(ctx); }),
          ListTile(title: const Text('Light'), leading: const Icon(Icons.light_mode), onTap: () { ref.read(themeModeProvider.notifier).setLight(); Navigator.pop(ctx); }),
          ListTile(title: const Text('Dark'), leading: const Icon(Icons.dark_mode), onTap: () { ref.read(themeModeProvider.notifier).setDark(); Navigator.pop(ctx); }),
        ],
      ),
    );
  }

  ImageProvider? _networkAvatarImage(AppUser? user, String baseUrl) {
    final avatarUrl = user?.avatarUrl?.trim();
    if (avatarUrl == null || avatarUrl.isEmpty) return null;

    final serverBaseUrl = ref.read(serverBaseUrlProvider);
    final fullUrl = avatarUrl.startsWith('http') 
        ? avatarUrl 
        : '$serverBaseUrl${avatarUrl.startsWith('/') ? '' : '/'}$avatarUrl';
    
    return NetworkImage(fullUrl);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                ),
          ),
        ),
      ],
    );
  }
}
