import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// StateNotifier that manages the app theme
class ThemeNotifier extends StateNotifier<AppColors> {
  ThemeNotifier() : super(AppTheme.darkRedTheme) {
    _loadTheme();
  }

  static const String _themeKey = 'app_theme_index';

  /// Load saved theme from SharedPreferences
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      state = AppTheme.getThemeByIndex(themeIndex);
    } catch (e) {
      print('Error loading theme: $e');
    }
  }

  /// Set new theme and save to SharedPreferences
  Future<void> setTheme(AppColors theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = AppTheme.getThemeIndex(theme);
      await prefs.setInt(_themeKey, themeIndex);
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  /// Set theme by index
  Future<void> setThemeByIndex(int index) async {
    final theme = AppTheme.getThemeByIndex(index);
    await setTheme(theme);
  }
}

/// Global theme provider
final themeProvider = StateNotifierProvider<ThemeNotifier, AppColors>((ref) {
  return ThemeNotifier();
});

/// Theme index provider for conditional styling
final themeIndexProvider = Provider<int>((ref) {
  final theme = ref.watch(themeProvider);
  return AppTheme.getThemeIndex(theme);
});
