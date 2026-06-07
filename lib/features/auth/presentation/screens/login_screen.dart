import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pageController = PageController(initialPage: 1);
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final authNotifier = ref.read(authControllerProvider.notifier);
    final success = await authNotifier.login(email, password);

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
        String error = state?.error ?? 'Login failed';
        
        // Enhance connection error messages for mobile troubleshooting
        if (error.contains('SocketException') || error.contains('connection refused') || error.contains('Network is unreachable')) {
          error = 'Connection to server failed. If you are on a real device, ensure the backend IP is correct in dio_client.dart.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text(error),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ));
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
                  return _buildLoginForm(theme, authState, true);
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
              return _buildLoginForm(theme, authState, false);
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
                'The minimalist learning management system for high-performing teams and academic institutions.',
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

  Widget _buildLoginForm(ThemeData theme, AsyncValue authState, bool isDesktop) {
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
                'Welcome back',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your credentials to access your account',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 32),

              // Login button
              MinimalButton(
                onPressed: authState.isLoading ? null : _login,
                color: AppColors.primary,
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Continue',
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

              // Social Logins
              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Sign in with Google',
                color: isDark ? AppColors.darkSurface : Colors.white,
                textColor: theme.colorScheme.onSurface,
                onPressed: () => ref.read(authControllerProvider.notifier).loginWithGoogle(),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "New to Class IQ? ",
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => context.pushNamed('register'),
                    child: const Text(
                      'Create account',
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
