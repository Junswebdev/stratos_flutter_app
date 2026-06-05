import 'package:flutter/material.dart';
import '../theme.dart';

class MinimalContainer extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxShape shape;
  final bool showBorder;
  final bool showShadow;
  final bool showHighlighter; // New: Adds a subtle accent highlight

  const MinimalContainer({
    super.key,
    this.child,
    this.borderRadius = 24,
    this.color,
    this.padding,
    this.margin,
    this.shape = BoxShape.rectangle,
    this.showBorder = false,
    this.showShadow = false,
    this.showHighlighter = true, // Default to true for better visuals
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // In light mode: white card with soft drop shadow (reference design style)
    // In dark mode: dark card with subtle border
    final effectiveColor = color ?? (isDark ? AppColors.darkCard : Colors.white);
    final hasBorder = showBorder || isDark;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        border: hasBorder
            ? Border.all(color: theme.colorScheme.outline, width: 1)
            : null,
        boxShadow: (!isDark && (showShadow || showHighlighter))
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class MinimalButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double width;
  final double? height;

  const MinimalButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius = 12,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.width = double.infinity,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = color ?? theme.colorScheme.primary;
    final onColor = bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: onColor,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: onColor,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          child: child,
        ),
      ),
    );
  }
}

class MinimalTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const MinimalTextField({
    super.key,
    this.controller,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
        contentPadding: theme.inputDecorationTheme.contentPadding,
      ),
    );
  }
}

class SafeAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final String fallbackText;
  final Color? fallbackTextColor;
  final double? fontSize;

  const SafeAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.fallbackText,
    this.backgroundColor,
    this.fallbackTextColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.14);
    final textColor = fallbackTextColor ?? theme.colorScheme.primary;
    final size = radius * 2;

    final fallback = Text(
      fallbackText,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
      ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: (imageUrl != null && imageUrl!.isNotEmpty)
          ? ClipOval(
              child: Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            )
          : fallback,
    );
  }
}

class MinimalStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  const MinimalStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? AppColors.darkCard
        : (color ?? getPastelColor(label));

    // Derive an icon/accent color from the pastel background
    final accentColor = isDark ? theme.colorScheme.primary : AppColors.primary;

    return MinimalContainer(
      padding: const EdgeInsets.all(20),
      color: bgColor,
      borderRadius: 24,
      showHighlighter: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isDark ? theme.colorScheme.primary : AppColors.primary,
              size: 22,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: isDark ? theme.colorScheme.onSurfaceVariant : AppColors.textBody,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 28,
              color: isDark ? theme.colorScheme.onSurface : AppColors.textHeader,
            ),
          ),
        ],
      ),
    );
  }
}
