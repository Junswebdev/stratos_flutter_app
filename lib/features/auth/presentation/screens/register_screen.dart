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
  final _pageController = PageController(initialPage: 0);
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/background.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.primary.withValues(alpha: 0.1),
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            );
          },
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(isMobile ? 32.0 : 64.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_stories,
                size: isMobile ? 64 : 80,
                color: Colors.white,
              ),
              const SizedBox(height: 32),
              Text(
                'Join Stratos',
                textAlign: isMobile ? TextAlign.center : TextAlign.start,
                style: (isMobile ? theme.textTheme.displaySmall : theme.textTheme.displayMedium)
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Start your journey with us today. Access\nworld-class courses, expert instructors,\nand a community of passionate learners.',
                textAlign: isMobile ? TextAlign.center : TextAlign.start,
                style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)
                    ?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
              ),
              if (isMobile) ...[
                const SizedBox(height: 64),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Swipe to create account',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
                  ],
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome text
              Text(
                'Create Account',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join Stratos and start learning',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),

              // Name field
              MinimalTextField(
                controller: _nameController,
                labelText: 'Full Name (Optional)',
                prefixIcon: Icon(Icons.person_outline, size: 20, color: theme.colorScheme.primary),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Email field
              MinimalTextField(
                controller: _emailController,
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, size: 20, color: theme.colorScheme.primary),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Password field
              MinimalTextField(
                controller: _passwordController,
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outlined, size: 20, color: theme.colorScheme.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Role selector
              MinimalContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.badge_outlined, size: 20, color: theme.colorScheme.primary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: UserRole.student,
                      child: Text('Student'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.instructor,
                      child: Text('Instructor'),
                    ),
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
                color: theme.colorScheme.primary,
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
              const SizedBox(height: 32),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: theme.colorScheme.outline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: theme.colorScheme.outline)),
                ],
              ),
              const SizedBox(height: 32),

              // Social Logins
              _SocialButton(
                icon: Icons.g_mobiledata,
                label: 'Sign up with Google',
                color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.grey.shade100,
                textColor: isDark ? Colors.white : Colors.black,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).loginWithGoogle(),
              ),
              const SizedBox(height: 32),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.goNamed('login');
                      }
                    },
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
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
