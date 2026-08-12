import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings för optional workout features
class WorkoutSettings {
  final bool showRIR;
  final bool showProgression;

  /// Visar den flytande vilotimern under passet.
  ///
  /// Default är PÅ, till skillnad från de två ovan: den som inte vill ha den
  /// stänger av den en gång, medan den som har nytta av den slipper leta reda
  /// på den först.
  final bool showRestTimer;

  const WorkoutSettings({
    this.showRIR = false,
    this.showProgression = false,
    this.showRestTimer = true,
  });

  WorkoutSettings copyWith({
    bool? showRIR,
    bool? showProgression,
    bool? showRestTimer,
  }) {
    return WorkoutSettings(
      showRIR: showRIR ?? this.showRIR,
      showProgression: showProgression ?? this.showProgression,
      showRestTimer: showRestTimer ?? this.showRestTimer,
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
  static const String _keyShowRestTimer = 'show_rest_timer';

  /// Ladda settings från SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = WorkoutSettings(
        showRIR: prefs.getBool(_keyShowRIR) ?? false,
        showProgression: prefs.getBool(_keyShowProgression) ?? false,
        showRestTimer: prefs.getBool(_keyShowRestTimer) ?? true,
      );
    } catch (e) {
      debugPrint('Error loading workout settings: $e');
    }
  }

  /// Toggle RIR visibility
  Future<void> toggleShowRIR(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowRIR, value);
      state = state.copyWith(showRIR: value);
    } catch (e) {
      debugPrint('Error saving RIR setting: $e');
    }
  }

  /// Toggle Progression visibility
  Future<void> toggleShowProgression(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowProgression, value);
      state = state.copyWith(showProgression: value);
    } catch (e) {
      debugPrint('Error saving progression setting: $e');
    }
  }

  /// Toggle the floating rest timer on the active workout screen.
  Future<void> toggleShowRestTimer(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowRestTimer, value);
      state = state.copyWith(showRestTimer: value);
    } catch (e) {
      debugPrint('Error saving rest timer setting: $e');
    }
  }
}

/// Provider för workout settings
final workoutSettingsProvider = StateNotifierProvider<WorkoutSettingsNotifier, WorkoutSettings>((ref) {
  return WorkoutSettingsNotifier();
});
