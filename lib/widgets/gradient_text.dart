import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class GradientText extends ConsumerWidget {
  final String text;
  final TextStyle style;
  final int currentThemeIndex;

  const GradientText({
    Key? key,
    required this.text,
    required this.style,
    required this.currentThemeIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    
    // Only show gradient in pink theme (theme index 1), otherwise use regular text
    if (currentThemeIndex == 1) { // Pink theme
      return ShaderMask(
        shaderCallback: (bounds) => theme.primaryGradient.createShader(bounds),
        child: Text(
          text,
          style: style.copyWith(
            color: Colors.white, // This will be masked by the gradient
          ),
        ),
      );
    } else {
      // Regular text for red theme
      return Text(
        text,
        style: style.copyWith(color: theme.text),
      );
    }
  }
}
