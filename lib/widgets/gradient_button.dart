import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class GradientButton extends ConsumerWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final TextStyle? textStyle;
  final double borderRadius;

  const GradientButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.width,
    this.height,
    this.padding,
    this.textStyle,
    this.borderRadius = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final themeIndex = ref.watch(themeIndexProvider);
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Use gradient only in pink theme (index 1), solid color in red theme (index 0)
        gradient: themeIndex == 1
            ? const LinearGradient(
                colors: [
                  Color(0xFFEC4898), // Pink start (0%)
                  Color(0xFFF43F5F), // Pink end (100%)
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: themeIndex == 1 ? null : theme.primary, // Solid color for red theme
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: (textStyle ?? const TextStyle()).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}