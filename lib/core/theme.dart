import 'package:flutter/material.dart';

class AppColors {
  // Reference design palette
  static const Color primary = Color(0xFFF06060);    // Coral-red — instructor accent
  static const Color secondary = Color(0xFF4ECDC4);  // Teal — student accent
  static const Color amber = Color(0xFFFFCA28);      // Warm amber accent
  static const Color purple = Color(0xFF9575CD);     // Soft purple accent
  static const Color success = Color(0xFF4CAF50);
  static const Color danger = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFB300);
  static const Color orange = Color(0xFFEA580C);
  static const Color netflixRed = Color(0xFFE50914);

  // Light mode
  static const Color background = Color(0xFFEEF2F7);   // Light blue-gray (reference bg)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8EDF5);
  static const Color textHeader = Color(0xFF1E2D4A);   // Dark navy
  static const Color textBody = Color(0xFF3D4E67);
  static const Color textSecondary = Color(0xFF8A99B0);

  // Light mode stat card pastels (soft tints for dashboard tiles)
  static const Color pastelCoral = Color(0xFFFDE8E8);
  static const Color pastelBlue = Color(0xFFE8EEFF);
  static const Color pastelAmber = Color(0xFFFFF3E0);
  static const Color pastelTeal = Color(0xFFE0F7F4);
  static const Color pastelPurple = Color(0xFFF3E8FF);

  // Dark mode
  static const Color darkBackground = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF171B26);
  static const Color darkCard = Color(0xFF1E2333);
  static const Color darkBorder = Color(0xFF2A3147);
  static const Color darkTextHeader = Color(0xFFF0F4FF);
  static const Color darkTextBody = Color(0xFFB8C4D8);
  static const Color darkTextSecondary = Color(0xFF6E7D96);

  // Dark mode card tints
  static const Color cardLavender = Color(0xFF1E1539);
  static const Color cardBlue = Color(0xFF0A1628);
  static const Color cardPeach = Color(0xFF2D0A0F);
  static const Color cardMint = Color(0xFF051F18);
  static const Color cardAmber = Color(0xFF1F0E00);

  static const Color white = Colors.white;

  // Light pastels used by MinimalStatCard
  static const List<Color> cardPastels = [
    pastelCoral,
    pastelBlue,
    pastelAmber,
    pastelTeal,
    pastelPurple,
  ];

  static Color getShadowColor(Color base, {double intensity = 0.15}) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness - intensity).clamp(0.0, 1.0)).toColor();
  }

  static Color getHighlightColor(Color base, {double intensity = 0.15}) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + intensity).clamp(0.0, 1.0)).toColor();
  }
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(brightness: Brightness.light);
  static ThemeData get darkTheme => _buildTheme(brightness: Brightness.dark);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: const Color(0xFFFF8A80),       // Soft coral for dark
            onPrimary: Colors.black,
            secondary: const Color(0xFF80CBC4),     // Soft teal for dark
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
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w900,
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

      // White cards with soft shadow in light mode
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkCard : Colors.white,
        elevation: isDark ? 0 : 4,
        shadowColor: isDark
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.06),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide(color: AppColors.darkBorder, width: 1)
              : BorderSide.none,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
        hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Bottom navigation bar — clean white, matches reference
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        indicatorColor: isDark
            ? colorScheme.primary.withValues(alpha: 0.2)
            : colorScheme.primary.withValues(alpha: 0.1),
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        elevation: 8,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
                color: isDark
                    ? colorScheme.primary
                    : AppColors.textHeader,
                size: 22);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color:
                  isDark ? colorScheme.primary : AppColors.textHeader,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            );
          }
          return TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 10,
          );
        }),
      ),
    );
  }
}

Color getPastelColor(String input) {
  final hash = input.hashCode.abs();
  return AppColors.cardPastels[hash % AppColors.cardPastels.length];
}

Color getGradientColor(String input) => getPastelColor(input);
List<Color> getCardGradient(String input) =>
    [getPastelColor(input), getPastelColor(input).withValues(alpha: 0.8)];
