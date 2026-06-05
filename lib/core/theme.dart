import 'package:flutter/material.dart';

class AppColors {
  // Salesforce-inspired Lime-Dark palette
  static const Color primary = Color(0xFFC6FF00); // Vibrant Neon Lime highlighter
  static const Color secondary = Color(0xFFFFFFFF); // Pure White contrast
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFF97316);
  static const Color netflixRed = Color(0xFFE50914);
  
  // Dark accents (Tints for dark backgrounds)
  static const Color cardLavender = Color(0xFF1E1B4B);
  static const Color cardBlue = Color(0xFF083344);
  static const Color cardPeach = Color(0xFF450A0A);
  static const Color cardMint = Color(0xFF064E3B);
  static const Color cardAmber = Color(0xFF451A03);

  // High-contrast Light Mode (Modern Professional)
  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  
  static const Color textHeader = Color(0xFF0C0E14); // Almost Black
  static const Color textBody = Color(0xFF334155);
  static const Color textSecondary = Color(0xFF64748B);

  // High-end Dark Mode (Deep Charcoal-Black)
  static const Color darkBackground = Color(0xFF0C0E14); // Deep charcoal
  static const Color darkSurface = Color(0xFF161922);    // Elevated surfaces
  static const Color darkCard = Color(0xFF1C1F2B);       // Distinct cards
  static const Color darkBorder = Color(0xFF2E323E);     // Sophisticated border
  static const Color darkTextHeader = Color(0xFFFFFFFF);
  static const Color darkTextBody = Color(0xFFCBD5E1);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  static const Color white = Colors.white;

  // Neumorphic helpers (required for legacy compatibility)
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
  static ThemeData get lightTheme {
    return _buildTheme(brightness: Brightness.light);
  }

  static ThemeData get darkTheme {
    return _buildTheme(brightness: Brightness.dark);
  }

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.black,
            surface: AppColors.darkSurface,
            onSurface: AppColors.darkTextHeader,
            surfaceContainerHighest: AppColors.darkCard,
            onSurfaceVariant: AppColors.darkTextSecondary,
            outline: AppColors.darkBorder,
            outlineVariant: AppColors.darkBorder,
          )
        : ColorScheme.light(
            primary: Colors.black,
            onPrimary: Colors.white,
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
          side: BorderSide(
            color: colorScheme.outline,
            width: 1,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }
}

Color getPastelColor(String input) {
  final hash = input.hashCode.abs();
  return AppColors.cardPastels[hash % AppColors.cardPastels.length];
}

// Compatibility helpers for old design patterns
Color getGradientColor(String input) => getPastelColor(input);
List<Color> getCardGradient(String input) => [getPastelColor(input), getPastelColor(input).withValues(alpha: 0.8)];
