import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/providers/rest_timer_provider.dart';
import 'package:gym_app/providers/workout_settings_provider.dart';

/// The rest timer's derived state is pure, so the rules that matter — when it
/// reads as overtime, how the ring fills, what happens without a target — can
/// be pinned down without a widget tree or a real clock.
void main() {
  group('progress toward the target', () {
    test('fills proportionally and never exceeds one', () {
      const half = RestTimerState(elapsedSeconds: 60, targetSeconds: 120);
      const past = RestTimerState(elapsedSeconds: 300, targetSeconds: 120);

      expect(half.progress, 0.5);
      expect(past.progress, 1.0);
    });

    test('no target means no ring to fill', () {
      const state = RestTimerState(elapsedSeconds: 90, targetSeconds: 0);

      expect(state.progress, 0);
      expect(state.isOvertime, isFalse);
      expect(state.remainingSeconds, 0);
    });
  });

  group('overtime', () {
    test('starts exactly at the target, not after it', () {
      const justBefore = RestTimerState(elapsedSeconds: 119, targetSeconds: 120);
      const exactly = RestTimerState(elapsedSeconds: 120, targetSeconds: 120);

      expect(justBefore.isOvertime, isFalse);
      expect(exactly.isOvertime, isTrue);
    });

    test('the clock keeps climbing past the target', () {
      // The whole point: the timer does not stop or reset when it is reached,
      // so "how long did I actually rest" survives.
      const state = RestTimerState(elapsedSeconds: 245, targetSeconds: 120);

      expect(state.isOvertime, isTrue);
      expect(state.label, '4:05');
      expect(state.remainingSeconds, 0);
    });
  });

  group('remaining', () {
    test('counts down to zero and stops there', () {
      const state = RestTimerState(elapsedSeconds: 95, targetSeconds: 120);
      expect(state.remainingSeconds, 25);
    });
  });

  group('label', () {
    test('is minutes and zero-padded seconds', () {
      expect(const RestTimerState(elapsedSeconds: 0).label, '0:00');
      expect(const RestTimerState(elapsedSeconds: 9).label, '0:09');
      expect(const RestTimerState(elapsedSeconds: 65).label, '1:05');
      expect(const RestTimerState(elapsedSeconds: 600).label, '10:00');
    });
  });

  group('running', () {
    test('is defined by having a start time', () {
      expect(const RestTimerState().isRunning, isFalse);
      expect(
        RestTimerState(startedAt: DateTime(2025, 3, 20)).isRunning,
        isTrue,
      );
    });

    test('copyWith can clear the start time', () {
      final running = RestTimerState(
        startedAt: DateTime(2025, 3, 20),
        elapsedSeconds: 45,
      );

      expect(running.copyWith(clearStartedAt: true).isRunning, isFalse);
      // Without the explicit flag, a null start time must not wipe the old one.
      expect(running.copyWith(elapsedSeconds: 46).isRunning, isTrue);
    });
  });

  group('presets', () {
    test('offer a no-target option and are ordered', () {
      const presets = RestTimerNotifier.targetPresets;

      expect(presets.first, 0);
      expect(presets, contains(90));
      expect(presets, contains(180));
      for (var i = 1; i < presets.length; i++) {
        expect(presets[i], greaterThan(presets[i - 1]));
      }
    });
  });

  group('visibility setting', () {
    test('the rest timer is on by default, unlike the other extras', () {
      const defaults = WorkoutSettings();

      expect(defaults.showRestTimer, isTrue);
      expect(defaults.showRIR, isFalse);
      expect(defaults.showProgression, isFalse);
    });

    test('copyWith leaves the other toggles alone', () {
      const on = WorkoutSettings(showRIR: true, showProgression: true);
      final off = on.copyWith(showRestTimer: false);

      expect(off.showRestTimer, isFalse);
      expect(off.showRIR, isTrue);
      expect(off.showProgression, isTrue);
    });
  });
}
