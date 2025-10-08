import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings för optional workout features
class WorkoutSettings {
  final bool showRIR;
  final bool showProgression;

  const WorkoutSettings({
    this.showRIR = false,
    this.showProgression = false,
  });

  WorkoutSettings copyWith({
    bool? showRIR,
    bool? showProgression,
  }) {
    return WorkoutSettings(
      showRIR: showRIR ?? this.showRIR,
      showProgression: showProgression ?? this.showProgression,
    );
  }
}

/// StateNotifier för att hantera workout settings
class WorkoutSettingsNotifier extends StateNotifier<WorkoutSettings> {
  WorkoutSettingsNotifier() : super(const WorkoutSettings()) {
    _loadSettings();
  }

  static const String _keyShowRIR = 'show_rir';
  static const String _keyShowProgression = 'show_progression';

  /// Ladda settings från SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = WorkoutSettings(
        showRIR: prefs.getBool(_keyShowRIR) ?? false,
        showProgression: prefs.getBool(_keyShowProgression) ?? false,
      );
    } catch (e) {
      print('Error loading workout settings: $e');
    }
  }

  /// Toggle RIR visibility
  Future<void> toggleShowRIR(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowRIR, value);
      state = state.copyWith(showRIR: value);
    } catch (e) {
      print('Error saving RIR setting: $e');
    }
  }

  /// Toggle Progression visibility
  Future<void> toggleShowProgression(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowProgression, value);
      state = state.copyWith(showProgression: value);
    } catch (e) {
      print('Error saving progression setting: $e');
    }
  }
}

/// Provider för workout settings
final workoutSettingsProvider = StateNotifierProvider<WorkoutSettingsNotifier, WorkoutSettings>((ref) {
  return WorkoutSettingsNotifier();
});
