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
  // Dark Red theme (default)
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

  // Pink/White theme (EC4898 -> F43F5F)
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

  // Ocean Blue theme - Deep blues with elegant gradients
  static const oceanBlueTheme = AppColors(
    primary: Color(0xFF1E40AF),        // Deep ocean blue
    primaryLight: Color(0xFF3B82F6),   // Bright blue
    background: Color(0xFF0F172A),     // Deep navy background
    backgroundDark: Color(0xFF020617), // Almost black navy
    card: Color(0xFF1E293B),           // Dark blue-gray cards
    surface: Color(0xFF334155),        // Medium blue-gray surface
    accent: Color(0xFF60A5FA),         // Light blue accent
    text: Color(0xFFE2E8F0),           // Light blue-white text
    textSecondary: Color(0xFF94A3B8),  // Blue-gray secondary text
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  // Forest Green theme - Rich greens with nature vibes
  static const forestGreenTheme = AppColors(
    primary: Color(0xFF059669),        // Rich emerald green
    primaryLight: Color(0xFF10B981),   // Bright green
    background: Color(0xFF0C1E0F),     // Deep forest background
    backgroundDark: Color(0xFF064E3B), // Dark forest green
    card: Color(0xFF1F2937),           // Dark green-gray cards
    surface: Color(0xFF374151),        // Medium green-gray surface
    accent: Color(0xFF34D399),         // Light mint green accent
    text: Color(0xFFECFDF5),           // Light green-white text
    textSecondary: Color(0xFF9CA3AF),  // Green-gray secondary text
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  // Lavender Dreams theme - Soft feminine pinks with subtle lavender
  static const lavenderDreamsTheme = AppColors(
    primary: Color(0xFFE879F9),        // Soft pink-magenta
    primaryLight: Color(0xFFF0ABFC),   // Light pink-lavender
    background: Color(0xFFFDF2F8),     // Very light pink background
    backgroundDark: Color(0xFFFFFFFF), // Pure white
    card: Color(0xFFFFFFFF),           // White cards with subtle shadow
    surface: Color(0xFFFCE7F3),        // Light pink surface
    accent: Color(0xFFD946EF),         // Bright magenta accent
    text: Color(0xFF831843),           // Deep pink text
    textSecondary: Color(0xFFA21CAF),  // Medium pink for secondary text
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  // Purple Dream theme - Dark theme with vibrant purple gradients
  static const purpleDreamTheme = AppColors(
    primary: Color(0xFF9542EC),        // Vibrant purple
    primaryLight: Color(0xFFD946EF),   // Bright magenta-purple
    background: Color(0xFF1B1C20),     // Very dark blue-gray
    backgroundDark: Color(0xFF000000), // Pure black
    card: Color(0xFF2C2C2E),           // Dark gray cards
    surface: Color(0xFF1C1C1E),        // Slightly lighter dark
    accent: Color(0xFFD946EF),         // Bright magenta accent
    text: Color(0xFFFFFFFF),           // Pure white text
    textSecondary: Color(0xFFB3B3B3),  // Light gray secondary
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
  );

  // List of all available themes
  static const List<AppColors> allThemes = [
    darkRedTheme,
    pinkTheme,
    oceanBlueTheme,
    forestGreenTheme,
    lavenderDreamsTheme,
    purpleDreamTheme,
  ];

  // Theme names
  static const List<String> themeNames = [
    'Dark Red',
    'Pink',
    'Ocean Blue',
    'Forest Green',
    'Lavender Dreams',
    'Purple Dream',
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
