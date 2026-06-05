import 'package:flutter/material.dart';
import '../theme.dart';

enum NeumorphicDepth { elevated, recessed, flat }

class NeumorphicContainer extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final NeumorphicDepth depth;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double spread;
  final BoxShape shape;

  const NeumorphicContainer({
    super.key,
    this.child,
    this.borderRadius = 16,
    this.depth = NeumorphicDepth.elevated,
    this.color,
    this.padding,
    this.margin,
    this.blur = 12,
    this.spread = 1,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = color ?? theme.colorScheme.surface;
    final shadowColor = AppColors.getShadowColor(baseColor);
    final highlightColor = AppColors.getHighlightColor(baseColor);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        boxShadow: depth == NeumorphicDepth.flat
            ? []
            : [
                BoxShadow(
                  color: depth == NeumorphicDepth.elevated ? shadowColor : highlightColor,
                  offset: depth == NeumorphicDepth.elevated ? const Offset(4, 4) : const Offset(-4, -4),
                  blurRadius: blur,
                  spreadRadius: spread,
                ),
                BoxShadow(
                  color: depth == NeumorphicDepth.elevated ? highlightColor : shadowColor,
                  offset: depth == NeumorphicDepth.elevated ? const Offset(-4, -4) : const Offset(4, 4),
                  blurRadius: blur,
                  spreadRadius: spread,
                ),
              ],
        gradient: depth == NeumorphicDepth.recessed
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  shadowColor.withValues(alpha: 0.1),
                  highlightColor.withValues(alpha: 0.05),
                ],
              )
            : null,
      ),
      child: child,
    );
  }
}

class NeumorphicButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double width;
  final double? height;

  const NeumorphicButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius = 12,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.width = double.infinity,
    this.height = 50,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.color ?? theme.colorScheme.primary;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        constraints: BoxConstraints(
          minHeight: widget.height ?? 50,
        ),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _isPressed || widget.onPressed == null
              ? []
              : [
                  BoxShadow(
                    color: AppColors.getShadowColor(theme.colorScheme.surface, intensity: 0.15),
                    offset: const Offset(4, 4),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: AppColors.getHighlightColor(theme.colorScheme.surface, intensity: 0.15),
                    offset: const Offset(-4, -4),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Padding(
          padding: widget.padding,
          child: Center(
            child: DefaultTextStyle(
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class NeumorphicTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const NeumorphicTextField({
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
    return NeumorphicContainer(
      depth: NeumorphicDepth.recessed,
      borderRadius: 12,
      blur: 4,
      spread: 0,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
