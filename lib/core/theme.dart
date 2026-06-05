import 'package:flutter/material.dart';

class AppColors {
  // Modern Violet + Cyan palette
  static const Color primary = Color(0xFF7C3AED);    // Violet-600 — instructor accent
  static const Color secondary = Color(0xFF0891B2);  // Cyan-600 — student accent
  static const Color success = Color(0xFF059669);    // Emerald-600
  static const Color danger = Color(0xFFDC2626);     // Red-600
  static const Color warning = Color(0xFFD97706);    // Amber-600
  static const Color orange = Color(0xFFEA580C);     // Orange-600
  static const Color netflixRed = Color(0xFFE50914);

  // Dark card tints
  static const Color cardLavender = Color(0xFF1E1539);
  static const Color cardBlue = Color(0xFF0A1628);
  static const Color cardPeach = Color(0xFF2D0A0F);
  static const Color cardMint = Color(0xFF051F18);
  static const Color cardAmber = Color(0xFF1F0E00);

  // Light mode
  static const Color background = Color(0xFFF5F3FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEDE9FE);
  static const Color textHeader = Color(0xFF1E0A3C);
  static const Color textBody = Color(0xFF3B2F6E);
  static const Color textSecondary = Color(0xFF6D5FA6);

  // Dark mode — Deep Space
  static const Color darkBackground = Color(0xFF08071A);
  static const Color darkSurface = Color(0xFF100F26);
  static const Color darkCard = Color(0xFF16152E);
  static const Color darkBorder = Color(0xFF2D2A50);
  static const Color darkTextHeader = Color(0xFFF0EDFF);
  static const Color darkTextBody = Color(0xFFC4BCF0);
  static const Color darkTextSecondary = Color(0xFF8F87C2);

  static const Color white = Colors.white;

  static Color getShadowColor(Color base, {double intensity = 0.15}) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness - intensity).clamp(0.0, 1.0)).toColor();
  }

  static Color getHighlightColor(Color base, {double intensity = 0.15}) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + intensity).clamp(0.0, 1.0)).toColor();
  }

  static const List<Color> cardPastels = [
    cardLavender,
    cardBlue,
    cardPeach,
    cardMint,
    cardAmber,
  ];
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(brightness: Brightness.light);
  static ThemeData get darkTheme => _buildTheme(brightness: Brightness.dark);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: const Color(0xFFA78BFA),      // Violet-400
            onPrimary: Colors.black,
            secondary: const Color(0xFF22D3EE),    // Cyan-400
            onSecondary: Colors.black,
            surface: AppColors.darkSurface,
            onSurface: AppColors.darkTextHeader,
            surfaceContainerHighest: AppColors.darkCard,
            onSurfaceVariant: AppColors.darkTextSecondary,
            outline: AppColors.darkBorder,
            outlineVariant: AppColors.darkBorder,
          )
        : ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.secondary,
            onSecondary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textHeader,
            surfaceContainerHighest: AppColors.surface,
            onSurfaceVariant: AppColors.textSecondary,
            outline: AppColors.border,
            outlineVariant: AppColors.border,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['SF Pro Display', 'Roboto', 'Helvetica Neue'],

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: colorScheme.onSurface,
          letterSpacing: -1.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -1.0,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: colorScheme.onSurface,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

Color getPastelColor(String input) {
  final hash = input.hashCode.abs();
  return AppColors.cardPastels[hash % AppColors.cardPastels.length];
}

Color getGradientColor(String input) => getPastelColor(input);
List<Color> getCardGradient(String input) => [getPastelColor(input), getPastelColor(input).withValues(alpha: 0.8)];
