import 'package:flutter/material.dart';

class AppColors {
  // Primary minimalist accent: Mustard Gold
  static const Color primary = Color(0xFFEAB308);    
  static const Color secondary = Color(0xFFFBBF24);  
  
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFF97316);
  static const Color netflixRed = danger; // Legacy alias for quiz screens

  // Light mode - Grayscale & Soft White
  static const Color background = Color(0xFFF9FAFB);   // Soft white/gray bg
  static const Color surface = Color(0xFFFFFFFF);      // Pure white cards
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);       // Subtle gray border
  static const Color textHeader = Color(0xFF111827);   // Almost black
  static const Color textBody = Color(0xFF4B5563);     // Dark gray
  static const Color textSecondary = Color(0xFF9CA3AF); // Mid gray

  // Light mode stat card solid colors (Muted minimalist tones)
  static const Color pastelCoral = Color(0xFFF3F4F6); // Gray 100
  static const Color pastelBlue = Color(0xFFF3F4F6);
  static const Color pastelAmber = Color(0xFFFEF3C7); // Pale gold tint
  static const Color pastelTeal = Color(0xFFF3F4F6);
  static const Color pastelPurple = Color(0xFFF3F4F6);

  // Dark mode - Deep Grayscale
  static const Color darkBackground = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF1C1C1C);
  static const Color darkCard = Color(0xFF1C1C1C);
  static const Color darkBorder = Color(0xFF2D2D2D);
  static const Color darkTextHeader = Color(0xFFF9FAFB);
  static const Color darkTextBody = Color(0xFFD1D5DB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Dark mode card solid tints (Muted darks)
  static const Color cardLavender = Color(0xFF262626);
  static const Color cardBlue = Color(0xFF262626);
  static const Color cardPeach = Color(0xFF452B08); // Dark gold tint
  static const Color cardMint = Color(0xFF262626);
  static const Color cardAmber = Color(0xFF262626);

  static const Color white = Colors.white;

  static const List<Color> cardPastels = [
    pastelAmber,
    pastelCoral,
    pastelBlue,
    pastelTeal,
    pastelPurple,
  ];

  static Color getShadowColor(Color base, {double intensity = 0.05}) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness - intensity).clamp(0.0, 1.0)).toColor();
  }

  static Color getHighlightColor(Color base, {double intensity = 0.05}) {
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
            primary: AppColors.primary,       
            onPrimary: Colors.black,
            secondary: AppColors.secondary,     
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
            onPrimary: Colors.black, // Dark text on gold button
            secondary: AppColors.secondary,
            onSecondary: Colors.black,
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
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: -0.4,
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

      // Flat, minimalist cards with smaller border radius
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 1.0,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        indicatorColor: isDark
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.primary.withValues(alpha: 0.1),
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
        elevation: 4,
        height: 60,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
                color: isDark
                    ? colorScheme.primary
                    : AppColors.textHeader,
                size: 20);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 20);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color:
                  isDark ? colorScheme.primary : AppColors.textHeader,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            );
          }
          return TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 11,
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
    [getPastelColor(input), getPastelColor(input)];

