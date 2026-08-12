import 'dart:math' as math;

import '../models/training_goals.dart';
import '../models/workout_session_model.dart';
import '../utils/one_rm_calculator.dart';

export '../models/training_goals.dart';

/// ---------------------------------------------------------------------------
/// AnalyticsService — every derived training statistic in the app.
///
/// Deliberately *pure*: it takes a list of [WorkoutSession] and returns plain
/// value objects. Nothing here touches Firestore. The session list is fetched
/// exactly once (see `providers/analytics_provider.dart`) and every screen
/// computes from that snapshot, instead of each stats page re-reading the whole
/// collection — which is what the old per-metric database methods did.
/// ---------------------------------------------------------------------------
class AnalyticsService {
  AnalyticsService._();

  // --- Primitives ------------------------------------------------------------

  /// A set counts toward statistics only if it was actually performed and is
  /// not a warm-up. This rule is applied identically everywhere.
  static bool isWorkingSet(CompletedSet s) =>
      !s.isWarmUp && s.weight > 0 && s.reps > 0;

  static double setVolume(CompletedSet s) => s.weight * s.reps;

  /// Total tonnage (kg lifted) in a session.
  static double sessionVolume(WorkoutSession session) {
    var total = 0.0;
    for (final ex in session.completedExercises) {
      for (final s in ex.sets) {
        if (isWorkingSet(s)) total += setVolume(s);
      }
    }
    return total;
  }

  static int sessionWorkingSets(WorkoutSession session) {
    var count = 0;
    for (final ex in session.completedExercises) {
      count += ex.sets.where(isWorkingSet).length;
    }
    return count;
  }

  static int sessionReps(WorkoutSession session) {
    var count = 0;
    for (final ex in session.completedExercises) {
      for (final s in ex.sets) {
        if (isWorkingSet(s)) count += s.reps;
      }
    }
    return count;
  }

  /// Heaviest single working set in a session, across all exercises.
  static double sessionTopSet(WorkoutSession session) {
    var top = 0.0;
    for (final ex in session.completedExercises) {
      for (final s in ex.sets) {
        if (isWorkingSet(s) && s.weight > top) top = s.weight;
      }
    }
    return top;
  }

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday-based start of the week containing [d].
  static DateTime weekStart(DateTime d) {
    final day = dayOf(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  // --- Period summaries ------------------------------------------------------

  /// Builds the headline summary for [range], including the change against the
  /// immediately preceding window of the same length.
  static PeriodSummary summarize(
    List<WorkoutSession> allSessions,
    DateRange range,
  ) {
    final current = sessionsIn(allSessions, range);
    final previous = sessionsIn(allSessions, range.previous());

    return PeriodSummary(
      range: range,
      current: _aggregate(current),
      previous: _aggregate(previous),
    );
  }

  static List<WorkoutSession> sessionsIn(
    List<WorkoutSession> sessions,
    DateRange range,
  ) {
    return sessions.where((s) => range.contains(s.date)).toList();
  }

  static PeriodTotals _aggregate(List<WorkoutSession> sessions) {
    var volume = 0.0;
    var minutes = 0;
    var sets = 0;
    var reps = 0;
    final days = <DateTime>{};

    for (final s in sessions) {
      volume += sessionVolume(s);
      minutes += s.durationInMinutes;
      sets += sessionWorkingSets(s);
      reps += sessionReps(s);
      days.add(dayOf(s.date));
    }

    return PeriodTotals(
      workouts: sessions.length,
      volume: volume,
      minutes: minutes,
      sets: sets,
      reps: reps,
      activeDays: days.length,
    );
  }

  // --- Time series -----------------------------------------------------------

  /// Volume bucketed per week, oldest first. Weeks with no training are
  /// included as zeros so the chart shows the gaps honestly.
  static List<TimeBucket> weeklyVolume(
    List<WorkoutSession> sessions, {
    int weeks = 12,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final thisWeek = weekStart(ref);
    final buckets = <TimeBucket>[];

    for (var i = weeks - 1; i >= 0; i--) {
      final start = thisWeek.subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      final inWeek = sessions.where(
        (s) => !s.date.isBefore(start) && s.date.isBefore(end),
      );

      var volume = 0.0;
      var sets = 0;
      var count = 0;
      for (final s in inWeek) {
        volume += sessionVolume(s);
        sets += sessionWorkingSets(s);
        count++;
      }

      buckets.add(TimeBucket(
        start: start,
        end: end,
        volume: volume,
        sets: sets,
        workouts: count,
      ));
    }
    return buckets;
  }

  /// Same as [weeklyVolume] but per calendar month.
  static List<TimeBucket> monthlyVolume(
    List<WorkoutSession> sessions, {
    int months = 6,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final buckets = <TimeBucket>[];

    for (var i = months - 1; i >= 0; i--) {
      final start = DateTime(ref.year, ref.month - i, 1);
      final end = DateTime(start.year, start.month + 1, 1);
      final inMonth = sessions.where(
        (s) => !s.date.isBefore(start) && s.date.isBefore(end),
      );

      var volume = 0.0;
      var sets = 0;
      var count = 0;
      for (final s in inMonth) {
        volume += sessionVolume(s);
        sets += sessionWorkingSets(s);
        count++;
      }

      buckets.add(TimeBucket(
        start: start,
        end: end,
        volume: volume,
        sets: sets,
        workouts: count,
      ));
    }
    return buckets;
  }

  // --- Consistency -----------------------------------------------------------

  /// Current and longest streaks measured in *weeks* with at least
  /// [sessionsPerWeek] sessions — a far more useful streak for lifting than
  /// consecutive days, which punishes rest days.
  static StreakInfo weeklyStreak(
    List<WorkoutSession> sessions, {
    int sessionsPerWeek = 1,
    DateTime? now,
  }) {
    if (sessions.isEmpty) {
      return const StreakInfo(current: 0, longest: 0, thisWeek: 0);
    }

    final ref = now ?? DateTime.now();
    final counts = <DateTime, int>{};
    for (final s in sessions) {
      final w = weekStart(s.date);
      counts[w] = (counts[w] ?? 0) + 1;
    }

    final thisWeek = weekStart(ref);
    final earliest = counts.keys.reduce((a, b) => a.isBefore(b) ? a : b);

    // Walk backwards from this week for the current streak. The current week
    // is not yet over, so it only breaks the streak once it is in the past.
    var current = 0;
    var cursor = thisWeek;
    while (!cursor.isBefore(earliest)) {
      final hit = (counts[cursor] ?? 0) >= sessionsPerWeek;
      if (hit) {
        current++;
      } else if (cursor != thisWeek) {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 7));
    }

    // Longest streak across all weeks between the first and the current one.
    var longest = 0;
    var run = 0;
    var walk = earliest;
    while (!walk.isAfter(thisWeek)) {
      if ((counts[walk] ?? 0) >= sessionsPerWeek) {
        run++;
        longest = math.max(longest, run);
      } else {
        run = 0;
      }
      walk = walk.add(const Duration(days: 7));
    }

    return StreakInfo(
      current: current,
      longest: longest,
      thisWeek: counts[thisWeek] ?? 0,
    );
  }

  /// Which of the last 7 days (oldest first) had a session.
  static List<bool> lastSevenDays(
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) {
    final ref = dayOf(now ?? DateTime.now());
    final trained = sessions.map((s) => dayOf(s.date)).toSet();
    return [
      for (var i = 6; i >= 0; i--)
        trained.contains(ref.subtract(Duration(days: i)))
    ];
  }

  /// Average sessions per week over the trailing [weeks] window.
  static double weeklyFrequency(
    List<WorkoutSession> sessions, {
    int weeks = 8,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final start = weekStart(ref).subtract(Duration(days: 7 * (weeks - 1)));
    final count = sessions.where((s) => !s.date.isBefore(start)).length;
    return count / weeks;
  }

  /// Which weekday the user trains most often (1 = Monday).
  static Map<int, int> weekdayDistribution(List<WorkoutSession> sessions) {
    final map = <int, int>{for (var i = 1; i <= 7; i++) i: 0};
    for (final s in sessions) {
      map[s.date.weekday] = (map[s.date.weekday] ?? 0) + 1;
    }
    return map;
  }

  // --- Per exercise ----------------------------------------------------------

  /// Every distinct exercise name in the history, sorted by how recently it
  /// was trained (most recent first) — a far more useful order for pickers
  /// than alphabetical.
  static List<String> exerciseNamesByRecency(List<WorkoutSession> sessions) {
    final lastSeen = <String, DateTime>{};
    for (final s in sessions) {
      for (final ex in s.completedExercises) {
        final prev = lastSeen[ex.name];
        if (prev == null || s.date.isAfter(prev)) lastSeen[ex.name] = s.date;
      }
    }
    final names = lastSeen.keys.toList();
    names.sort((a, b) => lastSeen[b]!.compareTo(lastSeen[a]!));
    return names;
  }

  /// Builds the full progress picture for one exercise: every session it
  /// appeared in, the estimated 1RM curve, the trend, and PR detection.
  static ExerciseProgress exerciseProgress(
    List<WorkoutSession> sessions,
    String exerciseName, {
    OneRMFormula formula = OneRMFormula.epley,
  }) {
    final points = <ExercisePoint>[];

    for (final session in sessions) {
      CompletedExercise? match;
      for (final ex in session.completedExercises) {
        if (ex.name == exerciseName) {
          match = ex;
          break;
        }
      }
      if (match == null) continue;

      final working = match.sets.where(isWorkingSet).toList();
      if (working.isEmpty) continue;

      var topWeight = 0.0;
      var topReps = 0;
      var bestOneRm = 0.0;
      var volume = 0.0;

      for (final s in working) {
        volume += setVolume(s);
        if (s.weight > topWeight) {
          topWeight = s.weight;
          topReps = s.reps;
        }
        // Very high rep sets make 1RM estimates unreliable.
        if (s.reps <= 12) {
          final est = OneRMCalculator.calculate(s.weight, s.reps, formula);
          if (est > bestOneRm) bestOneRm = est;
        }
      }

      points.add(ExercisePoint(
        date: session.date,
        sessionId: session.id,
        programTitle: session.programTitle,
        topWeight: topWeight,
        topWeightReps: topReps,
        estimatedOneRm: bestOneRm,
        volume: volume,
        sets: working.length,
        reps: working.fold<int>(0, (sum, s) => sum + s.reps),
      ));
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return ExerciseProgress(name: exerciseName, points: points);
  }

  /// Progress for every exercise in one pass. Much cheaper than calling
  /// [exerciseProgress] per name when you need the whole library.
  static Map<String, ExerciseProgress> allExerciseProgress(
    List<WorkoutSession> sessions, {
    OneRMFormula formula = OneRMFormula.epley,
  }) {
    final byExercise = <String, List<ExercisePoint>>{};

    for (final session in sessions) {
      for (final ex in session.completedExercises) {
        final working = ex.sets.where(isWorkingSet).toList();
        if (working.isEmpty) continue;

        var topWeight = 0.0;
        var topReps = 0;
        var bestOneRm = 0.0;
        var volume = 0.0;

        for (final s in working) {
          volume += setVolume(s);
          if (s.weight > topWeight) {
            topWeight = s.weight;
            topReps = s.reps;
          }
          if (s.reps <= 12) {
            final est = OneRMCalculator.calculate(s.weight, s.reps, formula);
            if (est > bestOneRm) bestOneRm = est;
          }
        }

        byExercise.putIfAbsent(ex.name, () => []).add(ExercisePoint(
              date: session.date,
              sessionId: session.id,
              programTitle: session.programTitle,
              topWeight: topWeight,
              topWeightReps: topReps,
              estimatedOneRm: bestOneRm,
              volume: volume,
              sets: working.length,
              reps: working.fold<int>(0, (sum, s) => sum + s.reps),
            ));
      }
    }

    return {
      for (final entry in byExercise.entries)
        entry.key: ExerciseProgress(
          name: entry.key,
          points: entry.value..sort((a, b) => a.date.compareTo(b.date)),
        ),
    };
  }

  /// Least-squares slope of [values] against [days] since the first point,
  /// i.e. change per day. Multiply by 7 for "per week".
  static double linearSlope(List<double> xs, List<double> ys) {
    if (xs.length < 2 || xs.length != ys.length) return 0;
    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;

    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = xs[i] - meanX;
      numerator += dx * (ys[i] - meanY);
      denominator += dx * dx;
    }
    if (denominator.abs() < 1e-9) return 0;
    return numerator / denominator;
  }

  // --- Records ---------------------------------------------------------------

  /// All-time personal records, one per exercise, newest first.
  static List<PersonalBest> personalBests(
    List<WorkoutSession> sessions, {
    OneRMFormula formula = OneRMFormula.epley,
  }) {
    final progress = allExerciseProgress(sessions, formula: formula);
    final bests = <PersonalBest>[];

    for (final p in progress.values) {
      if (p.points.isEmpty) continue;
      final heaviest =
          p.points.reduce((a, b) => b.topWeight > a.topWeight ? b : a);
      final strongest =
          p.points.reduce((a, b) => b.estimatedOneRm > a.estimatedOneRm ? b : a);
      final biggest = p.points.reduce((a, b) => b.volume > a.volume ? b : a);

      bests.add(PersonalBest(
        exercise: p.name,
        weight: heaviest.topWeight,
        reps: heaviest.topWeightReps,
        date: heaviest.date,
        estimatedOneRm: strongest.estimatedOneRm,
        bestVolume: biggest.volume,
        lastPerformed: p.points.last.date,
        totalSessions: p.points.length,
      ));
    }

    bests.sort((a, b) => b.date.compareTo(a.date));
    return bests;
  }

  /// Records set inside [since] — the "recent wins" feed on the home screen.
  static List<PersonalBest> recentRecords(
    List<WorkoutSession> sessions, {
    Duration since = const Duration(days: 30),
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(since);
    return personalBests(sessions)
        .where((b) => b.date.isAfter(cutoff))
        .toList();
  }

  // --- Muscle groups ---------------------------------------------------------

  /// Working sets per muscle group inside [range].
  ///
  /// [exerciseToMuscle] maps an exercise name to its muscle group; exercises
  /// missing from the map are counted under [unmappedKey] so the user can see
  /// that some of their training is uncategorised rather than silently losing it.
  static Map<String, int> muscleGroupSets(
    List<WorkoutSession> sessions,
    Map<String, String> exerciseToMuscle, {
    DateRange? range,
    List<String> groups = defaultMuscleGroups,
    String unmappedKey = 'Other',
  }) {
    final counts = <String, int>{for (final g in groups) g: 0};
    counts[unmappedKey] = 0;

    for (final session in sessions) {
      if (range != null && !range.contains(session.date)) continue;
      for (final ex in session.completedExercises) {
        final working = ex.sets.where(isWorkingSet).length;
        if (working == 0) continue;
        final group = exerciseToMuscle[ex.name] ?? unmappedKey;
        counts[group] = (counts[group] ?? 0) + working;
      }
    }

    if (counts[unmappedKey] == 0) counts.remove(unmappedKey);
    return counts;
  }

  /// Average weekly sets per muscle group over the trailing [weeks] window,
  /// scored against the user's weekly set band from [goals] (10–20 by default,
  /// the evidence-based hypertrophy range).
  static List<MuscleBalance> muscleBalance(
    List<WorkoutSession> sessions,
    Map<String, String> exerciseToMuscle, {
    int weeks = 4,
    DateTime? now,
    List<String> groups = defaultMuscleGroups,
    TrainingGoals goals = const TrainingGoals(),
  }) {
    final ref = now ?? DateTime.now();
    final start = weekStart(ref).subtract(Duration(days: 7 * (weeks - 1)));
    final range = DateRange(start, ref);

    final totals = muscleGroupSets(
      sessions,
      exerciseToMuscle,
      range: range,
      groups: groups,
    );

    final result = <MuscleBalance>[];
    for (final group in groups) {
      final perWeek = (totals[group] ?? 0) / weeks;
      result.add(MuscleBalance(
        group: group,
        setsPerWeek: perWeek,
        totalSets: totals[group] ?? 0,
        targetMin: goals.setsMin,
        targetMax: goals.setsMax,
      ));
    }

    result.sort((a, b) => b.setsPerWeek.compareTo(a.setsPerWeek));
    return result;
  }

  /// The muscle groups that have drifted furthest below the recommended
  /// weekly volume — the actionable half of the balance analysis.
  static List<MuscleBalance> weakestGroups(
    List<MuscleBalance> balance, {
    int limit = 3,
  }) {
    final sorted = [...balance]
      ..sort((a, b) => a.setsPerWeek.compareTo(b.setsPerWeek));
    return sorted.where((m) => m.status != VolumeStatus.optimal).take(limit).toList();
  }

  static const List<String> defaultMuscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Quads',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Abs',
  ];

  // --- Programs --------------------------------------------------------------

  /// How often each program was run, most frequent first.
  static List<ProgramUsage> programUsage(List<WorkoutSession> sessions) {
    final counts = <String, int>{};
    final volumes = <String, double>{};
    final minutes = <String, int>{};
    final last = <String, DateTime>{};

    for (final s in sessions) {
      counts[s.programTitle] = (counts[s.programTitle] ?? 0) + 1;
      volumes[s.programTitle] =
          (volumes[s.programTitle] ?? 0) + sessionVolume(s);
      minutes[s.programTitle] =
          (minutes[s.programTitle] ?? 0) + s.durationInMinutes;
      final prev = last[s.programTitle];
      if (prev == null || s.date.isAfter(prev)) last[s.programTitle] = s.date;
    }

    final result = counts.entries
        .map((e) => ProgramUsage(
              title: e.key,
              count: e.value,
              totalVolume: volumes[e.key] ?? 0,
              totalMinutes: minutes[e.key] ?? 0,
              lastPerformed: last[e.key]!,
            ))
        .toList();

    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  // --- Insights --------------------------------------------------------------

  /// Turns the numbers into a short list of plain-language observations shown
  /// at the top of the Statistics tab.
  ///
  /// Sorted by [Insight.priority], so a caller with room for only the first two
  /// or three still gets the most useful ones. Nothing here is a model or a
  /// prediction — every entry is a threshold on the user's own history, and the
  /// thresholds are all visible in this method.
  static List<Insight> insights(
    List<WorkoutSession> sessions,
    Map<String, String> exerciseToMuscle, {
    DateTime? now,
    TrainingGoals goals = const TrainingGoals(),
  }) {
    final ref = now ?? DateTime.now();
    final out = <Insight>[];

    if (sessions.isEmpty) return out;

    // 1. Volume trend: this week against the same stretch of the weeks before
    //    it.
    //
    //    The current week is only part-finished, so the earlier weeks are cut
    //    off at today's weekday. Compared against four *complete* weeks, a
    //    single Monday session is always ~75% down, and the app announced a
    //    "lighter week" every Monday.
    final thisWeekStart = weekStart(ref);
    final daysElapsed = ref.weekday; // Mon = 1 … Sun = 7
    final firstWeek = weekStart(
      sessions.map((s) => s.date).reduce((a, b) => a.isBefore(b) ? a : b),
    );

    double weekToDate(DateTime start) {
      final end = start.add(Duration(days: daysElapsed));
      var total = 0.0;
      for (final s in sessions) {
        if (!s.date.isBefore(start) && s.date.isBefore(end)) {
          total += sessionVolume(s);
        }
      }
      return total;
    }

    // Weeks from before the user's first session are not light weeks, they are
    // no weeks. Averaging them in drags the baseline toward zero and turns an
    // ordinary week into a triple-digit jump.
    final priorWeeks = [
      for (var i = 1; i <= 4; i++) thisWeekStart.subtract(Duration(days: 7 * i))
    ].where((w) => !w.isBefore(firstWeek)).toList();

    if (priorWeeks.length >= 2) {
      final thisWeek = weekToDate(thisWeekStart);
      final priorAvg = priorWeeks.map(weekToDate).reduce((a, b) => a + b) /
          priorWeeks.length;

      if (priorAvg > 0 && thisWeek > 0) {
        final change = ((thisWeek - priorAvg) / priorAvg) * 100;
        final baseline = '${priorWeeks.length}-week average';

        if (change >= 15) {
          out.add(Insight(
            kind: InsightKind.positive,
            priority: InsightPriority.volumeClimb,
            title: 'Volume is climbing',
            message:
                'By this point in the week you are ${change.round()}% above '
                'your $baseline. Keep an eye on recovery.',
          ));
        } else if (change <= -25) {
          out.add(Insight(
            kind: InsightKind.warning,
            priority: InsightPriority.volumeDrop,
            title: 'Lighter week',
            message:
                'You are ${change.abs().round()}% below your $baseline for '
                'this point in the week. A deload is fine — just do not let '
                'it drift.',
          ));
        }
      }
    }

    // 2. Streak.
    final streak =
        weeklyStreak(sessions, sessionsPerWeek: goals.sessionsPerWeek, now: ref);
    if (streak.current >= 3) {
      out.add(Insight(
        kind: InsightKind.positive,
        priority: InsightPriority.streak,
        title: '${streak.current}-week streak',
        message: goals.sessionsPerWeek == 1
            ? 'You have trained every week for ${streak.current} weeks.'
            : 'You have hit ${goals.sessionsLabel} a week for '
                '${streak.current} weeks.',
      ));
    }

    // 3. Under-trained muscle groups, against the user's own floor.
    final balance =
        muscleBalance(sessions, exerciseToMuscle, now: ref, goals: goals);
    final trained = balance.where((b) => b.totalSets > 0).toList();
    if (trained.length >= 3) {
      final weakest = trained.last;
      if (weakest.status == VolumeStatus.low) {
        out.add(Insight(
          kind: InsightKind.suggestion,
          priority: InsightPriority.laggingMuscle,
          title: '${weakest.group} is lagging',
          message:
              'Only ${weakest.setsPerWeek.toStringAsFixed(1)} sets/week over the '
              'last month. Your goal is ${goals.weeklySetsMin} or more.',
        ));
      }
    }

    // 4. Stalled lifts. [ExerciseProgress.isStalled] already requires enough
    //    sessions to judge, so the only extra filter is recency.
    final progress = allExerciseProgress(sessions);
    final stalled = progress.values
        .where((p) => p.isStalled && p.isRecent(ref))
        .toList();
    if (stalled.isNotEmpty) {
      stalled.sort((a, b) => b.points.length.compareTo(a.points.length));
      out.add(Insight(
        kind: InsightKind.suggestion,
        priority: InsightPriority.plateau,
        title: '${stalled.first.name} has plateaued',
        message:
            'No estimated 1RM improvement across the last '
            '${ExerciseProgress.stallWindow} sessions. '
            'Try changing reps, rest or exercise order.',
      ));
    }

    // 5. Recent PRs.
    final prs = recentRecords(sessions, since: const Duration(days: 14), now: ref);
    if (prs.isNotEmpty) {
      out.add(Insight(
        kind: InsightKind.positive,
        priority: InsightPriority.personalRecord,
        title: prs.length == 1
            ? 'New PR: ${prs.first.exercise}'
            : '${prs.length} new PRs',
        message: prs.length == 1
            ? '${prs.first.weight.toStringAsFixed(prs.first.weight % 1 == 0 ? 0 : 1)} kg × ${prs.first.reps}'
            : 'You set personal bests in ${prs.take(3).map((p) => p.exercise).join(', ')}.',
      ));
    }

    // The rules above run in the order that reads best. What the user sees is
    // ranked instead, because the screen only has room for the first few — a new
    // PR used to be dropped whenever volume, streak and muscle balance all had
    // something to say. `List.sort` is not stable, so ties fall back to the
    // order the rules ran in.
    final ranked = out.asMap().entries.toList()
      ..sort((a, b) {
        final byPriority = b.value.priority.compareTo(a.value.priority);
        return byPriority != 0 ? byPriority : a.key.compareTo(b.key);
      });

    return [for (final e in ranked) e.value];
  }
}

/// ---------------------------------------------------------------------------
/// Value objects
/// ---------------------------------------------------------------------------

/// A closed date window: `start <= date <= end`. Both ends are inclusive.
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  bool contains(DateTime d) => !d.isBefore(start) && !d.isAfter(end);

  Duration get length => end.difference(start);

  /// The window of the same length immediately before this one.
  DateRange previous() {
    final span = length;
    return DateRange(start.subtract(span), start.subtract(const Duration(milliseconds: 1)));
  }

  static DateRange lastDays(int days, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    return DateRange(
      DateTime(ref.year, ref.month, ref.day).subtract(Duration(days: days - 1)),
      ref,
    );
  }

  static DateRange thisMonth({DateTime? now}) {
    final ref = now ?? DateTime.now();
    return DateRange(DateTime(ref.year, ref.month, 1), ref);
  }

  static DateRange allTime({DateTime? now}) {
    return DateRange(DateTime(2000), now ?? DateTime.now());
  }
}

/// The periods offered by the segmented control on stats screens.
enum StatsPeriod { week, month, quarter, year, all }

extension StatsPeriodX on StatsPeriod {
  String get label => switch (this) {
        StatsPeriod.week => '7d',
        StatsPeriod.month => '30d',
        StatsPeriod.quarter => '90d',
        StatsPeriod.year => '1y',
        StatsPeriod.all => 'All',
      };

  String get longLabel => switch (this) {
        StatsPeriod.week => 'Last 7 days',
        StatsPeriod.month => 'Last 30 days',
        StatsPeriod.quarter => 'Last 90 days',
        StatsPeriod.year => 'Last year',
        StatsPeriod.all => 'All time',
      };

  DateRange range({DateTime? now}) => switch (this) {
        StatsPeriod.week => DateRange.lastDays(7, now: now),
        StatsPeriod.month => DateRange.lastDays(30, now: now),
        StatsPeriod.quarter => DateRange.lastDays(90, now: now),
        StatsPeriod.year => DateRange.lastDays(365, now: now),
        StatsPeriod.all => DateRange.allTime(now: now),
      };
}

class PeriodTotals {
  final int workouts;
  final double volume;
  final int minutes;
  final int sets;
  final int reps;
  final int activeDays;

  const PeriodTotals({
    required this.workouts,
    required this.volume,
    required this.minutes,
    required this.sets,
    required this.reps,
    required this.activeDays,
  });

  double get hours => minutes / 60.0;
  double get avgDuration => workouts == 0 ? 0 : minutes / workouts;
  double get avgVolume => workouts == 0 ? 0 : volume / workouts;

  /// Tonnage per minute — how dense the sessions were.
  double get density => minutes == 0 ? 0 : volume / minutes;
}

class PeriodSummary {
  final DateRange range;
  final PeriodTotals current;
  final PeriodTotals previous;

  const PeriodSummary({
    required this.range,
    required this.current,
    required this.previous,
  });

  static double _pct(num now, num before) {
    if (before == 0) return now == 0 ? 0 : 100;
    return ((now - before) / before) * 100;
  }

  double get workoutsChange => _pct(current.workouts, previous.workouts);
  double get volumeChange => _pct(current.volume, previous.volume);
  double get minutesChange => _pct(current.minutes, previous.minutes);
  double get setsChange => _pct(current.sets, previous.sets);
  bool get hasComparison => previous.workouts > 0;
}

class TimeBucket {
  final DateTime start;
  final DateTime end;
  final double volume;
  final int sets;
  final int workouts;

  const TimeBucket({
    required this.start,
    required this.end,
    required this.volume,
    required this.sets,
    required this.workouts,
  });
}

class StreakInfo {
  final int current;
  final int longest;
  final int thisWeek;

  const StreakInfo({
    required this.current,
    required this.longest,
    required this.thisWeek,
  });
}

class ExercisePoint {
  final DateTime date;
  final String sessionId;
  final String programTitle;
  final double topWeight;
  final int topWeightReps;
  final double estimatedOneRm;
  final double volume;
  final int sets;
  final int reps;

  const ExercisePoint({
    required this.date,
    required this.sessionId,
    required this.programTitle,
    required this.topWeight,
    required this.topWeightReps,
    required this.estimatedOneRm,
    required this.volume,
    required this.sets,
    required this.reps,
  });
}

class ExerciseProgress {
  final String name;
  final List<ExercisePoint> points;

  const ExerciseProgress({required this.name, required this.points});

  bool get isEmpty => points.isEmpty;

  ExercisePoint? get latest => points.isEmpty ? null : points.last;
  ExercisePoint? get first => points.isEmpty ? null : points.first;

  double get bestWeight => points.isEmpty
      ? 0
      : points.map((p) => p.topWeight).reduce(math.max);

  double get bestOneRm => points.isEmpty
      ? 0
      : points.map((p) => p.estimatedOneRm).reduce(math.max);

  double get bestVolume =>
      points.isEmpty ? 0 : points.map((p) => p.volume).reduce(math.max);

  /// Change in estimated 1RM per week, from a least-squares fit over the
  /// whole history. Positive means the lift is trending up.
  double get oneRmPerWeek {
    if (points.length < 2) return 0;
    final origin = points.first.date;
    final xs = points
        .map((p) => p.date.difference(origin).inHours / 24.0)
        .toList();
    final ys = points.map((p) => p.estimatedOneRm).toList();
    return AnalyticsService.linearSlope(xs, ys) * 7;
  }

  /// Percentage gain in estimated 1RM from the first session to the latest.
  double get totalGainPercent {
    if (points.length < 2) return 0;
    final start = points.first.estimatedOneRm;
    if (start <= 0) return 0;
    return ((points.last.estimatedOneRm - start) / start) * 100;
  }

  /// How many trailing sessions are checked for a new best. The UI quotes this
  /// number, so it lives here rather than as prose in three places.
  static const int stallWindow = 4;

  /// A session has to clear the old peak by this much to count as progress.
  /// Half a percent absorbs rounding in the estimate instead of reading it as a
  /// real improvement.
  static const double stallTolerance = 1.005;

  /// Sessions that produced a usable 1RM estimate.
  ///
  /// A session built entirely from sets above 12 reps has no estimate at all
  /// (see [AnalyticsService.exerciseProgress]), so its `estimatedOneRm` is 0.
  /// Left in, every such session counts as "no improvement" and a high-rep
  /// block gets reported as a plateau. They are skipped instead.
  List<ExercisePoint> get ratedPoints =>
      points.where((p) => p.estimatedOneRm > 0).toList(growable: false);

  /// True when the last [stallWindow] rated sessions produced no new estimated
  /// 1RM best.
  ///
  /// Needs *more* than [stallWindow] rated sessions: a stall is measured against
  /// an earlier peak, and with exactly four sessions there is nothing before the
  /// window to beat.
  bool get isStalled {
    final rated = ratedPoints;
    if (rated.length <= stallWindow) return false;

    final recent = rated.sublist(rated.length - stallWindow);
    final peakBefore = rated
        .sublist(0, rated.length - stallWindow)
        .fold<double>(0, (m, p) => math.max(m, p.estimatedOneRm));
    return recent.every((p) => p.estimatedOneRm <= peakBefore * stallTolerance);
  }

  /// Trained within the last month — used to avoid nagging about lifts the
  /// user has deliberately dropped.
  bool isRecent(DateTime now) =>
      points.isNotEmpty && now.difference(points.last.date).inDays <= 30;

  List<double> get oneRmSeries =>
      points.map((p) => p.estimatedOneRm).toList(growable: false);

  List<double> get weightSeries =>
      points.map((p) => p.topWeight).toList(growable: false);

  List<double> get volumeSeries =>
      points.map((p) => p.volume).toList(growable: false);
}

class PersonalBest {
  final String exercise;
  final double weight;
  final int reps;
  final DateTime date;
  final double estimatedOneRm;
  final double bestVolume;
  final DateTime lastPerformed;
  final int totalSessions;

  const PersonalBest({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.date,
    required this.estimatedOneRm,
    required this.bestVolume,
    required this.lastPerformed,
    required this.totalSessions,
  });
}

enum VolumeStatus { none, low, optimal, high }

class MuscleBalance {
  final String group;
  final double setsPerWeek;
  final int totalSets;

  /// The weekly working-set band this group was scored against. Carried on the
  /// result rather than read from a constant, because the band is the user's
  /// [TrainingGoals] — a chart drawn from these results can shade the right
  /// strip without having to look the goal up again.
  final double targetMin;
  final double targetMax;

  const MuscleBalance({
    required this.group,
    required this.setsPerWeek,
    required this.totalSets,
    this.targetMin = defaultTargetMin,
    this.targetMax = defaultTargetMax,
  });

  /// The band a user gets before they touch Settings: the broadly accepted
  /// hypertrophy range from the training literature.
  ///
  /// These mirror [TrainingGoals.defaultWeeklySetsMin]/[TrainingGoals.defaultWeeklySetsMax]
  /// as literals because Dart will not fold `int.toDouble()` in a const
  /// context. A test pins the two pairs together.
  static const double defaultTargetMin = 10;
  static const double defaultTargetMax = 20;

  VolumeStatus get status {
    if (setsPerWeek <= 0) return VolumeStatus.none;
    if (setsPerWeek < targetMin) return VolumeStatus.low;
    if (setsPerWeek > targetMax) return VolumeStatus.high;
    return VolumeStatus.optimal;
  }

  String get statusLabel => switch (status) {
        VolumeStatus.none => 'Not trained',
        VolumeStatus.low => 'Below target',
        VolumeStatus.optimal => 'On target',
        VolumeStatus.high => 'Above target',
      };
}

class ProgramUsage {
  final String title;
  final int count;
  final double totalVolume;
  final int totalMinutes;
  final DateTime lastPerformed;

  const ProgramUsage({
    required this.title,
    required this.count,
    required this.totalVolume,
    required this.totalMinutes,
    required this.lastPerformed,
  });

  double get avgVolume => count == 0 ? 0 : totalVolume / count;
  double get avgMinutes => count == 0 ? 0 : totalMinutes / count;
}

enum InsightKind { positive, warning, suggestion }

/// The ranking behind [Insight.priority], gathered in one place so the editorial
/// call — what a lifter most wants to see when only two or three fit on screen —
/// is visible as a list rather than spread across the rules that emit them.
///
/// Fresh and actionable outrank ambient: a PR you just set, or a lift that has
/// stopped moving, beats a streak that will still be there tomorrow.
abstract final class InsightPriority {
  static const int personalRecord = 100;
  static const int plateau = 90;
  static const int laggingMuscle = 80;
  static const int volumeDrop = 70;
  static const int volumeClimb = 60;
  static const int streak = 50;

  /// Fallback for an insight that does not opt into the ranking.
  static const int normal = 40;
}

class Insight {
  final InsightKind kind;
  final String title;
  final String message;

  /// Higher shows first. See [InsightPriority].
  final int priority;

  const Insight({
    required this.kind,
    required this.title,
    required this.message,
    this.priority = InsightPriority.normal,
  });
}
