import 'package:flutter/material.dart';

/// App color theme definitions
/// Supports multiple color schemes that can be switched dynamically
class AppColors {
  final Color primary;
  final Color primaryLight;
  final Color background;
  final Color backgroundDark;
  final Color card;
  final Color surface;
  final Color accent;
  final Color text;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color error;

  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.background,
    required this.backgroundDark,
    required this.card,
    required this.surface,
    required this.accent,
    required this.text,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.error,
  });

  /// Creates a MaterialColor swatch from the primary color
  MaterialColor toMaterialColor() {
    return MaterialColor(
      primary.value,
      {
        50: primaryLight.withOpacity(0.1),
        100: primaryLight.withOpacity(0.2),
        200: primaryLight.withOpacity(0.3),
        300: primaryLight.withOpacity(0.4),
        400: primaryLight.withOpacity(0.6),
        500: primary,
        600: primary.withOpacity(0.8),
        700: primary.withOpacity(0.7),
        800: primary.withOpacity(0.6),
        900: primary.withOpacity(0.5),
      },
    );
  }

  /// Creates the primary gradient from primary to primaryLight
  /// This is the EC4898 -> F43F5F gradient for pink theme
  LinearGradient get primaryGradient {
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [primary, primaryLight],
    );
  }

  /// Get gradient colors as a list (useful for containers)
  List<Color> get gradientColors => [primary, primaryLight];
}

/// Predefined app themes
class AppTheme {
  // Dark Red theme (default - your current colors)
  static const darkRedTheme = AppColors(
    primary: Color(0xFFDC2626),
    primaryLight: Color(0xFFEF4444),
    background: Color(0xFF0A0A0A),
    backgroundDark: Color(0xFF000000),
    card: Color(0xFF18181B),
    surface: Color(0xFF27272A),
    accent: Color(0xFFFA2F2F),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1AA),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  // Pink/White theme - from gradient image (EC4898 -> F43F5F)
  static const pinkTheme = AppColors(
    primary: Color(0xFFEC4898),        // Pink from gradient (0%)
    primaryLight: Color(0xFFF43F5F),   // Red from gradient (100%)
    background: Color(0xFFF8F9FA),     // Light gray/white background
    backgroundDark: Color(0xFFFFFFFF), // Pure white
    card: Color(0xFFFFFFFF),           // White cards
    surface: Color(0xFFF1F5F9),        // Very light surface
    accent: Color(0xFFF43F5F),         // Lighter pink-red
    text: Color(0xFF1F2937),           // Dark text for light backgrounds
    textSecondary: Color(0xFF6B7280),  // Gray text for secondary content
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  // List of all available themes
  static const List<AppColors> allThemes = [
    darkRedTheme,
    pinkTheme,
  ];

  // Theme names
  static const List<String> themeNames = [
    'Dark Red',
    'Pink',
  ];

  /// Get theme by index
  static AppColors getThemeByIndex(int index) {
    if (index < 0 || index >= allThemes.length) {
      return darkRedTheme;
    }
    return allThemes[index];
  }

  /// Get theme index by theme
  static int getThemeIndex(AppColors theme) {
    return allThemes.indexOf(theme);
  }
}
