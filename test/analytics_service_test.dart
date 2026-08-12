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

    test('a plateau needs a session before the window to compare against', () {
      List<WorkoutSession> flat(int count) => [
            for (var i = 0; i < count; i++)
              session(date: DateTime(2025, 1, 6 + i * 7), exercises: {
                'Row': [set(70, 5)],
              }),
          ];

      // Four flat sessions and nothing earlier is a short history, not a stall:
      // there is no previous peak to have failed to beat.
      expect(
        AnalyticsService.exerciseProgress(flat(4), 'Row').isStalled,
        isFalse,
      );
      expect(
        AnalyticsService.exerciseProgress(flat(5), 'Row').isStalled,
        isTrue,
      );
    });

    test('high-rep sessions are not counted as a failed attempt at a best', () {
      // Five sessions of real progression, then a block of 15-rep work. Sets
      // that high carry no 1RM estimate at all, and counting them as "no
      // improvement" reported a pump block as a plateau.
      final sessions = [
        for (var i = 0; i < 5; i++)
          session(date: DateTime(2025, 1, 6 + i * 7), exercises: {
            'Row': [set(60 + i * 5, 5)],
          }),
        for (var i = 0; i < 4; i++)
          session(date: DateTime(2025, 2, 10 + i * 7), exercises: {
            'Row': [set(40, 15)],
          }),
      ];

      final p = AnalyticsService.exerciseProgress(sessions, 'Row');
      expect(p.points.length, 9);
      expect(p.ratedPoints.length, 5);
      expect(p.isStalled, isFalse);
    });
  });

  group('insights', () {
    /// Mon/Wed/Fri for four straight weeks with identical sessions, then a
    /// single session on the fifth Monday. A perfectly consistent lifter.
    List<WorkoutSession> steadyWeeks({double mondayWeight = 100}) {
      return [
        for (var week = 0; week < 4; week++)
          for (final offset in [0, 2, 4])
            session(
              date: DateTime(2025, 1, 6).add(Duration(days: week * 7 + offset)),
              exercises: {
                'Bench Press': [set(100, 5)],
              },
            ),
        session(date: DateTime(2025, 2, 3), exercises: {
          'Bench Press': [set(mondayWeight, 5)],
        }),
      ];
    }

    final monday = DateTime(2025, 2, 3);

    test('a normal Monday is not reported as a lighter week', () {
      final result =
          AnalyticsService.insights(steadyWeeks(), const {}, now: monday);

      // The comparison used to put one Monday session against four *complete*
      // weeks, so a consistent lifter was told they were ~66% down every Monday.
      expect(result.where((i) => i.title == 'Lighter week'), isEmpty);
    });

    test('weeks before the first session do not inflate the baseline', () {
      final fresh = [
        session(date: DateTime(2025, 1, 27), exercises: {
          'Bench Press': [set(100, 5)],
        }),
        session(date: monday, exercises: {
          'Bench Press': [set(100, 5), set(100, 5)],
        }),
      ];

      final result = AnalyticsService.insights(fresh, const {}, now: monday);

      // Only one prior week exists. Averaging in three empty weeks turned a
      // second session into a several-hundred-percent jump.
      expect(
        result.where((i) =>
            i.title == 'Volume is climbing' || i.title == 'Lighter week'),
        isEmpty,
      );
    });

    test('a new PR outranks the ambient observations', () {
      final result = AnalyticsService.insights(
        steadyWeeks(mondayWeight: 110),
        const {},
        now: monday,
      );

      // The screen shows the first three. A PR set this week must not be pushed
      // out by a streak that will still be there tomorrow.
      expect(result.first.title, 'New PR: Bench Press');
      expect(result.map((i) => i.title), contains('5-week streak'));
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

    test('the default band is the same number in both places', () {
      // MuscleBalance repeats the defaults as literals because Dart will not
      // fold int.toDouble() in a const context. This is the pin that keeps the
      // two copies honest.
      expect(MuscleBalance.defaultTargetMin,
          TrainingGoals.defaultWeeklySetsMin.toDouble());
      expect(MuscleBalance.defaultTargetMax,
          TrainingGoals.defaultWeeklySetsMax.toDouble());
    });

    test('a custom band re-scores the same training', () {
      // Six working sets of chest a week: under the default band, comfortably
      // inside a maintenance band, over a very light one.
      final sessions = [
        for (var week = 0; week < 4; week++)
          session(date: DateTime(2025, 3, 18).subtract(Duration(days: 7 * week)),
              exercises: {
                'Bench Press': [set(100, 5), set(100, 5), set(100, 5)],
                'Incline Press': [set(60, 8), set(60, 8), set(60, 8)],
              }),
      ];
      const map = {'Bench Press': 'Chest', 'Incline Press': 'Chest'};
      final now = DateTime(2025, 3, 20);

      MuscleBalance chestUnder(TrainingGoals goals) {
        final balance = AnalyticsService.muscleBalance(
          sessions,
          map,
          now: now,
          goals: goals,
        );
        return balance.firstWhere((b) => b.group == 'Chest');
      }

      expect(chestUnder(const TrainingGoals()).setsPerWeek, 6);
      expect(chestUnder(const TrainingGoals()).status, VolumeStatus.low);
      expect(
        chestUnder(const TrainingGoals(weeklySetsMin: 6, weeklySetsMax: 10))
            .status,
        VolumeStatus.optimal,
      );
      expect(
        chestUnder(const TrainingGoals(weeklySetsMin: 2, weeklySetsMax: 5))
            .status,
        VolumeStatus.high,
      );
    });

    test('each result carries the band it was scored against', () {
      final balance = AnalyticsService.muscleBalance(
        const [],
        const {},
        goals: const TrainingGoals(weeklySetsMin: 4, weeklySetsMax: 9),
      );

      expect(balance, isNotEmpty);
      expect(balance.every((b) => b.targetMin == 4 && b.targetMax == 9), isTrue);
    });
  });

  group('training goals', () {
    test('the defaults reproduce the old hard-coded behaviour', () {
      const goals = TrainingGoals();

      expect(goals.weeklySetsMin, 10);
      expect(goals.weeklySetsMax, 20);
      expect(goals.sessionsPerWeek, 1);
      expect(goals.isDefault, isTrue);
      expect(goals.bandLabel, '10–20');
    });

    test('an inverted or out-of-range band is corrected, not accepted', () {
      // Max below min: the max is pushed back above the min rather than the
      // band silently rendering backwards on the charts.
      expect(TrainingGoals.band(15, 4).weeklySetsMin, 15);
      expect(TrainingGoals.band(15, 4).weeklySetsMax, 16);

      // Both ends clamp into range.
      expect(TrainingGoals.band(-5, 400).weeklySetsMin, TrainingGoals.minSets);
      expect(TrainingGoals.band(-5, 400).weeklySetsMax, TrainingGoals.maxSets);

      // A band can never collapse to a single number.
      final collapsed = TrainingGoals.band(12, 12);
      expect(collapsed.weeklySetsMax - collapsed.weeklySetsMin,
          greaterThanOrEqualTo(TrainingGoals.minBandWidth));
    });

    test('copyWith keeps the band ordered when one end moves past the other',
        () {
      const goals = TrainingGoals(weeklySetsMin: 8, weeklySetsMax: 12);

      expect(goals.copyWith(weeklySetsMin: 20).weeklySetsMax,
          greaterThan(goals.copyWith(weeklySetsMin: 20).weeklySetsMin));
    });

    test('sessions per week is clamped to something a week can hold', () {
      expect(TrainingGoals.band(10, 20, sessionsPerWeek: 0).sessionsPerWeek, 1);
      expect(
        TrainingGoals.band(10, 20, sessionsPerWeek: 99).sessionsPerWeek,
        TrainingGoals.maxSessionsPerWeek,
      );
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
