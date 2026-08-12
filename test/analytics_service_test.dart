import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/models/workout_session_model.dart';
import 'package:gym_app/services/analytics_service.dart';
import 'package:gym_app/theme/design_tokens.dart';

/// Tests for the statistics engine. Everything in [AnalyticsService] is pure,
/// so it can be verified without Firebase, a device, or a widget tree — which
/// makes it the one part of the app worth having automated tests for.

CompletedSet set(double weight, int reps, {bool warmUp = false}) =>
    CompletedSet(weight: weight, reps: reps, isWarmUp: warmUp);

WorkoutSession session({
  required DateTime date,
  String title = 'Push',
  int minutes = 60,
  Map<String, List<CompletedSet>> exercises = const {},
}) {
  return WorkoutSession(
    id: '${title}_${date.millisecondsSinceEpoch}',
    programTitle: title,
    date: date,
    durationInMinutes: minutes,
    completedExercises: exercises.entries
        .map((e) => CompletedExercise(name: e.key, sets: e.value))
        .toList(),
  );
}

void main() {
  group('working set rules', () {
    test('warm-ups and unfilled sets never count', () {
      expect(AnalyticsService.isWorkingSet(set(100, 5)), isTrue);
      expect(AnalyticsService.isWorkingSet(set(100, 5, warmUp: true)), isFalse);
      expect(AnalyticsService.isWorkingSet(set(0, 5)), isFalse);
      expect(AnalyticsService.isWorkingSet(set(100, 0)), isFalse);
    });

    test('session volume excludes warm-ups and empty sets', () {
      final s = session(
        date: DateTime(2025, 3, 10),
        exercises: {
          'Bench Press': [
            set(60, 10, warmUp: true), // ignored
            set(100, 5), // 500
            set(100, 4), // 400
            set(0, 0), // ignored
          ],
          'Dips': [set(20, 10)], // 200
        },
      );

      expect(AnalyticsService.sessionVolume(s), 1100);
      expect(AnalyticsService.sessionWorkingSets(s), 3);
      expect(AnalyticsService.sessionReps(s), 19);
      expect(AnalyticsService.sessionTopSet(s), 100);
    });
  });

  group('week handling', () {
    test('weeks start on Monday', () {
      // 2025-03-12 is a Wednesday.
      expect(
        AnalyticsService.weekStart(DateTime(2025, 3, 12, 18, 30)),
        DateTime(2025, 3, 10),
      );
      // A Monday is its own week start, with the time stripped.
      expect(
        AnalyticsService.weekStart(DateTime(2025, 3, 10, 6)),
        DateTime(2025, 3, 10),
      );
      // A Sunday belongs to the week that began six days earlier.
      expect(
        AnalyticsService.weekStart(DateTime(2025, 3, 16, 23, 59)),
        DateTime(2025, 3, 10),
      );
    });
  });

  group('period comparison', () {
    test('summarize compares against the preceding window of equal length', () {
      final now = DateTime(2025, 3, 20, 12);
      final sessions = [
        // Inside the last 7 days.
        session(date: DateTime(2025, 3, 19), exercises: {
          'Squat': [set(100, 5)], // 500
        }),
        session(date: DateTime(2025, 3, 17), exercises: {
          'Squat': [set(100, 5)], // 500
        }),
        // Inside the *previous* 7 days.
        session(date: DateTime(2025, 3, 11), exercises: {
          'Squat': [set(100, 5)], // 500
        }),
      ];

      final summary = AnalyticsService.summarize(
        sessions,
        DateRange.lastDays(7, now: now),
      );

      expect(summary.current.workouts, 2);
      expect(summary.previous.workouts, 1);
      expect(summary.current.volume, 1000);
      expect(summary.previous.volume, 500);
      expect(summary.volumeChange, 100); // +100%
      expect(summary.hasComparison, isTrue);
    });

    test('change against an empty previous window does not divide by zero', () {
      final now = DateTime(2025, 3, 20);
      final sessions = [
        session(date: DateTime(2025, 3, 19), exercises: {
          'Squat': [set(100, 5)],
        }),
      ];

      final summary =
          AnalyticsService.summarize(sessions, DateRange.lastDays(7, now: now));

      expect(summary.previous.workouts, 0);
      expect(summary.volumeChange, 100);
      expect(summary.hasComparison, isFalse);
    });
  });

  group('weekly buckets', () {
    test('empty weeks are reported as zero rather than skipped', () {
      final now = DateTime(2025, 3, 20); // Thursday, week of the 17th.
      final sessions = [
        session(date: DateTime(2025, 3, 18), exercises: {
          'Squat': [set(100, 5)],
        }),
        // Nothing in the week of the 10th.
        session(date: DateTime(2025, 3, 4), exercises: {
          'Squat': [set(100, 5)],
        }),
      ];

      final buckets =
          AnalyticsService.weeklyVolume(sessions, weeks: 3, now: now);

      expect(buckets.length, 3);
      expect(buckets[0].start, DateTime(2025, 3, 3));
      expect(buckets[0].workouts, 1);
      expect(buckets[1].workouts, 0); // the gap is visible
      expect(buckets[2].workouts, 1);
    });
  });

  group('streaks', () {
    test('the current week does not break a streak before it is over', () {
      final now = DateTime(2025, 3, 20); // week of the 17th, nothing logged yet
      final sessions = [
        session(date: DateTime(2025, 3, 12)),
        session(date: DateTime(2025, 3, 5)),
      ];

      final streak = AnalyticsService.weeklyStreak(sessions, now: now);

      expect(streak.thisWeek, 0);
      expect(streak.current, 2);
      expect(streak.longest, 2);
    });

    test('a missed week resets the current streak but not the longest', () {
      final now = DateTime(2025, 3, 20);
      final sessions = [
        session(date: DateTime(2025, 3, 18)), // this week
        // week of the 10th missed
        session(date: DateTime(2025, 3, 5)),
        session(date: DateTime(2025, 2, 26)),
        session(date: DateTime(2025, 2, 19)),
      ];

      final streak = AnalyticsService.weeklyStreak(sessions, now: now);

      expect(streak.current, 1);
      expect(streak.longest, 3);
    });

    test('no history yields zeros instead of throwing', () {
      final streak = AnalyticsService.weeklyStreak(const []);
      expect(streak.current, 0);
      expect(streak.longest, 0);
    });
  });

  group('exercise progress', () {
    final sessions = [
      session(date: DateTime(2025, 1, 6), exercises: {
        'Bench Press': [set(80, 5), set(80, 5)],
      }),
      session(date: DateTime(2025, 2, 3), exercises: {
        'Bench Press': [set(90, 5), set(85, 6)],
      }),
      session(date: DateTime(2025, 3, 3), exercises: {
        'Bench Press': [set(100, 5)],
      }),
    ];

    test('points are ordered oldest first and pick the heaviest set', () {
      final p = AnalyticsService.exerciseProgress(sessions, 'Bench Press');

      expect(p.points.length, 3);
      expect(p.points.first.date, DateTime(2025, 1, 6));
      expect(p.points.last.topWeight, 100);
      expect(p.points[1].topWeight, 90);
      expect(p.bestWeight, 100);
    });

    test('estimated 1RM rises with the load', () {
      final p = AnalyticsService.exerciseProgress(sessions, 'Bench Press');
      expect(p.points.last.estimatedOneRm,
          greaterThan(p.points.first.estimatedOneRm));
      expect(p.totalGainPercent, greaterThan(0));
      expect(p.oneRmPerWeek, greaterThan(0));
    });

    test('an unknown exercise produces an empty, safe result', () {
      final p = AnalyticsService.exerciseProgress(sessions, 'Nothing');
      expect(p.isEmpty, isTrue);
      expect(p.bestWeight, 0);
      expect(p.oneRmPerWeek, 0);
      expect(p.totalGainPercent, 0);
      expect(p.isStalled, isFalse);
    });

    test('allExerciseProgress matches the single-exercise path', () {
      final all = AnalyticsService.allExerciseProgress(sessions);
      final single = AnalyticsService.exerciseProgress(sessions, 'Bench Press');

      expect(all.keys, contains('Bench Press'));
      expect(all['Bench Press']!.points.length, single.points.length);
      expect(all['Bench Press']!.bestWeight, single.bestWeight);
    });

    test('a plateau is detected after four sessions without a new best', () {
      // One jump, then four identical sessions: the last four never beat the
      // peak that came before them.
      final flat = [
        for (var i = 0; i < 6; i++)
          session(date: DateTime(2025, 1, 6 + i * 7), exercises: {
            'Row': [set(i == 0 ? 60.0 : 70.0, 8)],
          }),
      ];

      final p = AnalyticsService.exerciseProgress(flat, 'Row');
      expect(p.points.length, 6);
      expect(p.isStalled, isTrue);
    });

    test('a lift that is still adding weight is not called a plateau', () {
      final climbing = [
        for (var i = 0; i < 6; i++)
          session(date: DateTime(2025, 1, 6 + i * 7), exercises: {
            'Row': [set(60 + i * 2.5, 8)],
          }),
      ];

      expect(
        AnalyticsService.exerciseProgress(climbing, 'Row').isStalled,
        isFalse,
      );
    });
  });

  group('personal bests', () {
    test('records the heaviest set per exercise with the date it was set', () {
      final sessions = [
        session(date: DateTime(2025, 3, 3), exercises: {
          'Deadlift': [set(180, 3)],
        }),
        session(date: DateTime(2025, 2, 3), exercises: {
          'Deadlift': [set(200, 1)],
        }),
      ];

      final bests = AnalyticsService.personalBests(sessions);
      final deadlift = bests.firstWhere((b) => b.exercise == 'Deadlift');

      expect(deadlift.weight, 200);
      expect(deadlift.reps, 1);
      expect(deadlift.date, DateTime(2025, 2, 3));
      expect(deadlift.totalSessions, 2);
      expect(deadlift.lastPerformed, DateTime(2025, 3, 3));
    });
  });

  group('muscle groups', () {
    final sessions = [
      session(date: DateTime(2025, 3, 18), exercises: {
        'Bench Press': [set(100, 5), set(100, 5)],
        'Mystery Machine': [set(50, 10)],
      }),
    ];

    test('unmapped exercises are surfaced rather than dropped', () {
      final counts = AnalyticsService.muscleGroupSets(
        sessions,
        {'Bench Press': 'Chest'},
      );

      expect(counts['Chest'], 2);
      expect(counts['Other'], 1);
    });

    test('the Other bucket disappears when everything is mapped', () {
      final counts = AnalyticsService.muscleGroupSets(
        sessions,
        {'Bench Press': 'Chest', 'Mystery Machine': 'Back'},
      );

      expect(counts.containsKey('Other'), isFalse);
      expect(counts['Back'], 1);
    });

    test('weekly volume is scored against the 10-20 set band', () {
      const none = MuscleBalance(group: 'Calves', setsPerWeek: 0, totalSets: 0);
      const low = MuscleBalance(group: 'Biceps', setsPerWeek: 6, totalSets: 24);
      const good = MuscleBalance(group: 'Chest', setsPerWeek: 14, totalSets: 56);
      const high = MuscleBalance(group: 'Back', setsPerWeek: 26, totalSets: 104);

      expect(none.status, VolumeStatus.none);
      expect(low.status, VolumeStatus.low);
      expect(good.status, VolumeStatus.optimal);
      expect(high.status, VolumeStatus.high);
    });
  });

  group('programs', () {
    test('usage is ranked by how often each program was run', () {
      final sessions = [
        session(date: DateTime(2025, 3, 18), title: 'Push', minutes: 60),
        session(date: DateTime(2025, 3, 16), title: 'Pull', minutes: 50),
        session(date: DateTime(2025, 3, 14), title: 'Push', minutes: 70),
      ];

      final usage = AnalyticsService.programUsage(sessions);

      expect(usage.first.title, 'Push');
      expect(usage.first.count, 2);
      expect(usage.first.avgMinutes, 65);
      expect(usage.first.lastPerformed, DateTime(2025, 3, 18));
    });
  });

  group('formatting', () {
    test('weights drop pointless decimals', () {
      expect(AppFormat.weight(80), '80');
      expect(AppFormat.weight(82.5), '82.5');
    });

    test('large numbers are compacted', () {
      expect(AppFormat.compact(950), '950');
      expect(AppFormat.compact(1240), '1.2k');
      expect(AppFormat.compact(12300), '12k');
      expect(AppFormat.compact(1500000), '1.5M');
    });

    test('durations read as hours and minutes', () {
      expect(AppFormat.duration(42), '42m');
      expect(AppFormat.duration(60), '1h');
      expect(AppFormat.duration(95), '1h 35m');
    });

    test('deltas carry an explicit sign', () {
      expect(AppFormat.delta(2.5, unit: 'kg'), '+2.5 kg');
      expect(AppFormat.delta(-1, unit: 'rep'), '−1 rep');
      expect(AppFormat.delta(0), '0');
    });

    test('relative dates are human readable', () {
      final now = DateTime(2025, 3, 20);
      expect(AppFormat.relativeDate(DateTime(2025, 3, 20), now: now), 'Today');
      expect(
          AppFormat.relativeDate(DateTime(2025, 3, 19), now: now), 'Yesterday');
      expect(
          AppFormat.relativeDate(DateTime(2025, 3, 17), now: now), '3 days ago');
    });
  });

  group('last seven days', () {
    test('returns oldest first and ends on today', () {
      final now = DateTime(2025, 3, 20, 21);
      final sessions = [
        session(date: DateTime(2025, 3, 20, 7)), // today
        session(date: DateTime(2025, 3, 18, 7)),
      ];

      final days = AnalyticsService.lastSevenDays(sessions, now: now);

      expect(days.length, 7);
      expect(days.last, isTrue); // today
      expect(days[5], isFalse); // the 19th
      expect(days[4], isTrue); // the 18th
    });
  });
}
