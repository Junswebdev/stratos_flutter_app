import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
import '../../domain/user_model.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pageController = PageController(initialPage: 1);
  bool _obscurePassword = true;
  UserRole _selectedRole = UserRole.student;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in required fields')),
      );
      return;
    }

    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.register(
      email,
      password,
      name.isEmpty ? null : name,
      role: _selectedRole,
    );

    if (mounted) {
      if (success) {
        final state = ref.read(authControllerProvider).value;
        final role = state?.role;
        if (role == 'instructor' || role == 'admin') {
          context.goNamed('courses');
        } else {
          context.goNamed('home');
        }
      } else {
        final state = ref.read(authControllerProvider).value;
        final error = state?.error;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error ?? 'Registration failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    if (isDesktop) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: Row(
          children: [
            Expanded(
              flex: 5,
              child: _buildIntroSection(theme),
            ),
            Expanded(
              flex: 4,
              child: Consumer(
                builder: (context, ref, _) {
                  final authState = ref.watch(authControllerProvider);
                  return _buildRegisterForm(theme, authState, true);
                },
              ),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet Swipable View
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: PageView(
        controller: _pageController,
        children: [
          _buildIntroSection(theme, isMobile: true),
          Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(authControllerProvider);
              return _buildRegisterForm(theme, authState, false);
            },
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(''),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: 'Toggle theme',
          icon: Icon(_themeIcon(ref.watch(themeModeProvider))),
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggle();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildIntroSection(ThemeData theme, {bool isMobile = false}) {
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFF111111)),
        Opacity(
          opacity: 0.4,
          child: Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(isMobile ? 32.0 : 64.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.black, size: 28),
              ),
              const SizedBox(height: 32),
              Text(
                'Class IQ',
                textAlign: isMobile ? TextAlign.center : TextAlign.start,
                style: (isMobile ? theme.textTheme.displaySmall : theme.textTheme.displayMedium)
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Start your journey with Class IQ - a modern, minimalist platform designed for academic excellence.',
                textAlign: isMobile ? TextAlign.center : TextAlign.start,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(ThemeData theme, AsyncValue authState, bool isDesktop) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Account',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign up to begin your learning experience',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // Name field
              MinimalTextField(
                controller: _nameController,
                labelText: 'Full name',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Email field
              MinimalTextField(
                controller: _emailController,
                labelText: 'Email address',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Password field
              MinimalTextField(
                controller: _passwordController,
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Role selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                   color: isDark ? AppColors.darkCard : Colors.white,
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Register as',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  items: const [
                    DropdownMenuItem(value: UserRole.student, child: Text('Student')),
                    DropdownMenuItem(value: UserRole.instructor, child: Text('Instructor')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedRole = v);
                  },
                ),
              ),
              const SizedBox(height: 40),

              // Register button
              MinimalButton(
                onPressed: authState.isLoading ? null : _register,
                color: AppColors.primary,
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                ],
              ),
              const SizedBox(height: 32),

              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Sign up with Google',
                color: isDark ? AppColors.darkSurface : Colors.white,
                textColor: theme.colorScheme.onSurface,
                onPressed: () => ref.read(authControllerProvider.notifier).loginWithGoogle(),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) context.pop();
                      else context.goNamed('login');
                    },
                    child: const Text(
                      'Sign in',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _themeIcon(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => Icons.brightness_auto,
    ThemeMode.dark => Icons.dark_mode,
    ThemeMode.light => Icons.light_mode,
  };
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
