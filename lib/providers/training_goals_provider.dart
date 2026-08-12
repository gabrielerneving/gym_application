import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_goals.dart';

export '../models/training_goals.dart';

/// ---------------------------------------------------------------------------
/// Where the user's [TrainingGoals] live.
///
/// Stored locally rather than in Firestore, like the rest timer and the workout
/// toggles: a goal is a preference about how you want to be measured, not
/// training data, and it should be there the instant the app opens rather than
/// after a round trip.
///
/// [trainingDataProvider] watches this, so changing a goal re-scores every
/// statistics screen without refetching a single session.
/// ---------------------------------------------------------------------------
class TrainingGoalsNotifier extends StateNotifier<TrainingGoals> {
  TrainingGoalsNotifier() : super(const TrainingGoals()) {
    _load();
  }

  static const String _keySetsMin = 'goal_weekly_sets_min';
  static const String _keySetsMax = 'goal_weekly_sets_max';
  static const String _keySessions = 'goal_sessions_per_week';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Through TrainingGoals.band so a hand-edited or half-written pref can
      // never produce an inverted band that the charts would draw backwards.
      state = TrainingGoals.band(
        prefs.getInt(_keySetsMin) ?? TrainingGoals.defaultWeeklySetsMin,
        prefs.getInt(_keySetsMax) ?? TrainingGoals.defaultWeeklySetsMax,
        sessionsPerWeek:
            prefs.getInt(_keySessions) ?? TrainingGoals.defaultSessionsPerWeek,
      );
    } catch (e) {
      debugPrint('Error loading training goals: $e');
    }
  }

  /// Sets the weekly working-set band. Ends are clamped and ordered, so the
  /// caller can pass a raw slider value without checking anything first.
  Future<void> setWeeklySetBand(int min, int max) async {
    final next = state.copyWith(weeklySetsMin: min, weeklySetsMax: max);
    if (next == state) return;
    state = next;
    await _persist();
  }

  /// Sets how many sessions a week have to be logged for the week to count
  /// toward the streak.
  Future<void> setSessionsPerWeek(int sessions) async {
    final next = state.copyWith(sessionsPerWeek: sessions);
    if (next == state) return;
    state = next;
    await _persist();
  }

  Future<void> applyPreset(SetBandPreset preset) =>
      setWeeklySetBand(preset.min, preset.max);

  Future<void> resetToDefaults() async {
    if (state.isDefault) return;
    state = const TrainingGoals();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySetsMin, state.weeklySetsMin);
      await prefs.setInt(_keySetsMax, state.weeklySetsMax);
      await prefs.setInt(_keySessions, state.sessionsPerWeek);
    } catch (e) {
      debugPrint('Error saving training goals: $e');
    }
  }
}

final trainingGoalsProvider =
    StateNotifierProvider<TrainingGoalsNotifier, TrainingGoals>((ref) {
  return TrainingGoalsNotifier();
});
