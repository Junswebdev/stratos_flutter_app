import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:stratos_app/data/dio_client.dart';
import 'package:stratos_app/core/theme.dart';
import 'package:stratos_app/core/theme_provider.dart';
import 'package:stratos_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:stratos_app/features/home/application/app_settings_provider.dart';
import 'package:stratos_app/features/home/application/home_providers.dart';
import 'package:stratos_app/features/home/data/home_models.dart';

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
    final dashboardInvoker = ref.invalidate;
    
    final success = await authNotifier.updateProfile(
      fullName: name,
      email: email,
    );
    if (!mounted) return;
    setState(() => _savingProfile = false);

    if (success) {
      dashboardInvoker(profileProvider);
      dashboardInvoker(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
      setState(() => _isEditingProfile = false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update profile')),
    );
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
    final dashboardInvoker = ref.invalidate;

    final success = await authNotifier.updateAvatar(
      imageBytes: file.bytes!,
      fileName: file.name,
    );
    if (!mounted) return;
    setState(() => _savingAvatar = false);

    if (success) {
      dashboardInvoker(profileProvider);
      dashboardInvoker(dashboardProvider);
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update avatar')),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a new password')),
        );
        return;
      }
      if (newPassword != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }

      final authNotifier = ref.read(authControllerProvider.notifier);
      final dashboardInvoker = ref.invalidate;
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
        dashboardInvoker(profileProvider);
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
    final appSettings = ref.watch(appSettingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final baseUrl = ref.watch(apiBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
      ),
      body: profileAsync.when(
        data: (user) {
          _syncControllers(user);

          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 1100 ? 980.0 : constraints.maxWidth;
              final isCompact = constraints.maxWidth < 720;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(user, themeMode, appSettings, baseUrl, isCompact),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Account'),
                        const SizedBox(height: 12),
                        _buildProfileCard(user, baseUrl, isCompact),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Appearance'),
                        const SizedBox(height: 12),
                        _buildAppearanceCard(themeMode, appSettings),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Security'),
                        const SizedBox(height: 12),
                        _buildSecurityCard(appSettings),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Maintenance'),
                        const SizedBox(height: 12),
                        _buildMaintenanceCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('System'),
                        const SizedBox(height: 12),
                        _buildSystemCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('About'),
                        const SizedBox(height: 12),
                        _buildAboutCard(baseUrl),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHero(AppUser? user, ThemeMode themeMode, AppSettings settings, String baseUrl, bool isCompact) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : _networkAvatarImage(user, baseUrl),
                    child: _avatarBytes == null
                        ? Text(
                            _displayInitial(user),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'User',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: [
                      _StatusChip(label: user?.role.toUpperCase() ?? 'STUDENT', color: AppColors.primary),
                      _StatusChip(label: 'Theme: ${_themeLabel(themeMode)}', color: AppColors.secondary),
                      _StatusChip(
                        label: settings.pushNotifications ? 'Notifications on' : 'Notifications off',
                        color: settings.pushNotifications ? AppColors.success : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : _networkAvatarImage(user, baseUrl),
                    child: _avatarBytes == null
                        ? Text(
                            _displayInitial(user),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'User',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.start,
                          children: [
                            _StatusChip(label: user?.role.toUpperCase() ?? 'STUDENT', color: AppColors.primary),
                            _StatusChip(label: 'Theme: ${_themeLabel(themeMode)}', color: AppColors.secondary),
                            _StatusChip(
                              label: settings.pushNotifications ? 'Notifications on' : 'Notifications off',
                              color: settings.pushNotifications ? AppColors.success : AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _buildProfileCard(AppUser? user, String baseUrl, bool isCompact) {
    final isEditing = _isEditingProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _savingAvatar ? null : () => _pickAvatar(user),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          foregroundImage: _avatarBytes != null
                              ? MemoryImage(_avatarBytes!)
                              : _networkAvatarImage(user, baseUrl),
                          child: _avatarBytes == null
                              ? Text(
                                  _displayInitial(user),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: _savingAvatar
                                ? const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Profile information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (!isCompact)
                    IconButton(
                      onPressed: _savingProfile
                          ? null
                          : () {
                              if (isEditing) {
                                _saveProfile(user);
                              } else {
                                setState(() => _isEditingProfile = true);
                              }
                            },
                      icon: Icon(isEditing ? Icons.check_rounded : Icons.edit_rounded),
                      tooltip: isEditing ? 'Save profile' : 'Edit profile',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_avatarFileName != null) ...[
                Text(
                  'Selected avatar: $_avatarFileName',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                enabled: isEditing,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Display name is required';
                  if (text.length < 2) return 'Use at least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                enabled: isEditing,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Email is required';
                  if (!text.contains('@') || !text.contains('.')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: user?.role,
                items: [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: null,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (isEditing) ...[
                    OutlinedButton(
                      onPressed: _savingProfile
                          ? null
                          : () {
                              _syncControllers(user);
                              setState(() => _isEditingProfile = false);
                            },
                      child: const Text('Cancel'),
                    ),
                  ],
                  FilledButton(
                    onPressed: _savingProfile
                        ? null
                        : () {
                            if (isEditing) {
                              _saveProfile(user);
                            } else {
                              setState(() => _isEditingProfile = true);
                            }
                          },
                    child: _savingProfile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Save profile' : 'Edit profile'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(ThemeMode themeMode, AppSettings settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visual preferences', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: themeMode,
              onChanged: (_) => ref.read(themeModeProvider.notifier).setSystem(),
              title: const Text('System'),
              subtitle: const Text('Follow the device theme'),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: themeMode,
              onChanged: (_) => ref.read(themeModeProvider.notifier).setLight(),
              title: const Text('Light'),
              subtitle: const Text('Use the light appearance'),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: themeMode,
              onChanged: (_) => ref.read(themeModeProvider.notifier).setDark(),
              title: const Text('Dark'),
              subtitle: const Text('Use the dark appearance'),
            ),
            const Divider(height: 24),
            SwitchListTile(
              value: settings.pushNotifications,
              onChanged: (value) => ref.read(appSettingsProvider.notifier).setNotifications(value),
              title: const Text('Push notifications'),
              subtitle: const Text('Receive updates for courses and announcements'),
            ),
            SwitchListTile(
              value: settings.biometricAuth,
              onChanged: (value) => ref.read(appSettingsProvider.notifier).setBiometric(value),
              title: const Text('Biometric unlock'),
              subtitle: const Text('Use fingerprint or face unlock when supported'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_rounded),
              title: const Text('Language'),
              subtitle: Text(settings.language == 'en' ? 'English (US)' : 'Spanish'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ref.read(appSettingsProvider.notifier).setLanguage(settings.language == 'en' ? 'es' : 'en');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(AppSettings settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Security controls', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_reset_rounded),
              title: const Text('Change password'),
              subtitle: const Text('Update your account password'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showChangePasswordDialog,
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.biometricAuth,
              onChanged: (value) => ref.read(appSettingsProvider.notifier).setBiometric(value),
              title: const Text('Biometric authentication'),
              subtitle: const Text('Enable biometrics on this device'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maintenance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Reset preferences'),
              subtitle: const Text('Restore theme, notification, language, and biometric settings'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _resetPreferences,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text('Sign out', style: TextStyle(color: Colors.red)),
              subtitle: const Text('End this session on the device'),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemCard() {
    final statusAsync = ref.watch(systemStatusProvider);
    final baseUrl = ref.watch(apiBaseUrlProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('System info', style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: () => ref.invalidate(systemStatusProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh status',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'App version', value: _appVersion),
            const SizedBox(height: 10),
            _InfoRow(label: 'API base URL', value: baseUrl),
            const SizedBox(height: 10),
            statusAsync.when(
              data: (status) => _InfoRow(
                label: 'Backend status',
                value: status.message,
                valueColor: status.isHealthy ? AppColors.success : AppColors.danger,
              ),
              loading: () => const _InfoRow(
                label: 'Backend status',
                value: 'Checking...',
                valueColor: AppColors.textSecondary,
              ),
              error: (error, _) => _InfoRow(
                label: 'Backend status',
                value: error.toString(),
                valueColor: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(String baseUrl) {
    final docsUrl = _docsUrl(baseUrl);
    final supportEmail = Uri(
      scheme: 'mailto',
      path: 'support@stratos.lms',
      queryParameters: {
        'subject': 'Stratos LMS support',
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About Stratos LMS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _InfoRow(label: 'App version', value: _appVersion),
            const SizedBox(height: 10),
            _InfoRow(label: 'Platform', value: 'Flutter client + FastAPI backend'),
            const SizedBox(height: 10),
            _InfoRow(label: 'Docs', value: docsUrl.toString()),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => launchUrl(docsUrl, mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open API Docs'),
                ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(supportEmail),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Contact Support'),
                ),
              ],
            ),
          ],
        ),
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

  Uri _docsUrl(String baseUrl) {
    final root = baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '/');
    return Uri.parse('${root}docs');
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
