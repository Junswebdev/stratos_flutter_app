import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/socket_service.dart';

void main() {
  runApp(const ProviderScope(child: StratosApp()));
}

class StratosApp extends ConsumerWidget {
  const StratosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize global services
    ref.watch(socketServiceProvider);
    
    final goRouter = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Stratos LMS',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
    );
  }
}
