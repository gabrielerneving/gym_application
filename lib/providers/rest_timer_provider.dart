import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// Rest timer.
///
/// Counts *up* from the moment a set is finished. A target can be set (90s,
/// 2min, …) but it only drives the ring and a nudge when you pass it — the
/// number keeps climbing, because "how long have I actually rested" stays
/// useful after the target is hit, and a timer that goes silent at zero is a
/// timer you stop trusting.
///
/// Lives in a provider rather than in the workout screen's state so it keeps
/// running when you back out to the home tab mid-rest.
/// ---------------------------------------------------------------------------
class RestTimerState {
  final DateTime? startedAt;

  /// Seconds since [startedAt]. Recomputed from the wall clock on every tick,
  /// so it stays correct if the app is backgrounded.
  final int elapsedSeconds;

  /// Target rest in seconds. 0 means "no target" — ring stays neutral.
  final int targetSeconds;

  /// Start automatically when a set is completed.
  final bool autoStart;

  const RestTimerState({
    this.startedAt,
    this.elapsedSeconds = 0,
    this.targetSeconds = 120,
    this.autoStart = true,
  });

  bool get isRunning => startedAt != null;

  /// True once the target has been passed. Null target never goes overtime.
  bool get isOvertime => targetSeconds > 0 && elapsedSeconds >= targetSeconds;

  /// 0..1 toward the target, clamped. Returns 0 when there is no target.
  double get progress {
    if (targetSeconds <= 0) return 0;
    return (elapsedSeconds / targetSeconds).clamp(0.0, 1.0);
  }

  /// Seconds remaining, or 0 once past the target.
  int get remainingSeconds =>
      targetSeconds <= 0 ? 0 : (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);

  /// "1:45" / "12:05".
  String get label {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  RestTimerState copyWith({
    DateTime? startedAt,
    bool clearStartedAt = false,
    int? elapsedSeconds,
    int? targetSeconds,
    bool? autoStart,
  }) {
    return RestTimerState(
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      autoStart: autoStart ?? this.autoStart,
    );
  }
}

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  RestTimerNotifier() : super(const RestTimerState()) {
    _loadPreferences();
  }

  static const String _keyTarget = 'rest_timer_target_seconds';
  static const String _keyAutoStart = 'rest_timer_auto_start';

  /// The presets offered in the picker. 0 = no target, just count up.
  static const List<int> targetPresets = [0, 60, 90, 120, 150, 180, 240, 300];

  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        targetSeconds: prefs.getInt(_keyTarget) ?? 120,
        autoStart: prefs.getBool(_keyAutoStart) ?? true,
      );
    } catch (e) {
      debugPrint('Error loading rest timer settings: $e');
    }
  }

  /// Starts (or restarts) the rest period. Calling this while already running
  /// resets to zero — finishing another set means a new rest, not a longer one.
  void start() {
    final now = DateTime.now();
    state = state.copyWith(startedAt: now, elapsedSeconds: 0);
    _startTicker();
  }

  /// Called when a set is completed. Respects the auto-start preference.
  void onSetCompleted() {
    if (!state.autoStart) return;
    start();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(clearStartedAt: true, elapsedSeconds: 0);
  }

  void toggle() {
    if (state.isRunning) {
      stop();
    } else {
      start();
    }
  }

  Future<void> setTarget(int seconds) async {
    state = state.copyWith(targetSeconds: seconds);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyTarget, seconds);
    } catch (e) {
      debugPrint('Error saving rest timer target: $e');
    }
  }

  Future<void> setAutoStart(bool value) async {
    state = state.copyWith(autoStart: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoStart, value);
    } catch (e) {
      debugPrint('Error saving rest timer auto-start: $e');
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final startedAt = state.startedAt;
      if (startedAt == null) {
        timer.cancel();
        _ticker = null;
        return;
      }

      final elapsed = DateTime.now().difference(startedAt).inSeconds;

      // A rest that has run for an hour is a forgotten timer, not a rest.
      if (elapsed >= 3600) {
        stop();
        return;
      }

      if (elapsed != state.elapsedSeconds) {
        state = state.copyWith(elapsedSeconds: elapsed);
      }
    });
  }
}

final restTimerProvider =
    StateNotifierProvider<RestTimerNotifier, RestTimerState>((ref) {
  return RestTimerNotifier();
});

/// Just the tick, for widgets that should rebuild once a second without
/// dragging the rest of the screen along.
final restElapsedProvider = Provider<int>((ref) {
  return ref.watch(restTimerProvider.select((s) => s.elapsedSeconds));
});

/// Whether a rest is in progress — cheap to watch from the shell.
final restRunningProvider = Provider<bool>((ref) {
  return ref.watch(restTimerProvider.select((s) => s.isRunning));
});
