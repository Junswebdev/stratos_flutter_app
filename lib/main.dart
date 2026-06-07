import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/socket_service.dart';
import 'core/utils/locale_provider.dart';

void main() {
  runApp(const ProviderScope(child: ClassIQApp()));
}

class ClassIQApp extends ConsumerWidget {
  const ClassIQApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize global services
    ref.watch(socketServiceProvider);
    
    final goRouter = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Class IQ',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('fil', 'PH'),
      ],
    );
  }
}
