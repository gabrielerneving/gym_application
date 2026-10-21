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

  /// A set counts as done when it has reps and is not a warm-up. Weight 0 is a
  /// bodyweight set (pull-ups, dips): it counts toward set and rep totals, adds
  /// nothing to tonnage, and never feeds a top weight, a 1RM or a weight PR.
  /// This rule is applied identically everywhere.
  static bool isWorkingSet(CompletedSet s) => !s.isWarmUp && s.reps > 0;

  /// A working set with load on it — the only kind that can produce a top
  /// weight, an estimated 1RM or a weight record.
  static bool isWeightedSet(CompletedSet s) => isWorkingSet(s) && s.weight > 0;

  /// Estimates from sets above this many reps are too unreliable to use.
  static const int maxOneRmReps = 12;

  static double setVolume(CompletedSet s) =>
      s.weight > 0 ? s.weight * s.reps : 0.0;

  /// True when at least one set of [exercise] was actually done. A skipped
  /// exercise — every set left empty — is not "trained".
  static bool exerciseHasWork(CompletedExercise exercise) =>
      exercise.sets.any(isWorkingSet);

  /// True when the session contains any working set at all.
  static bool hasWork(WorkoutSession session) =>
      session.completedExercises.any(exerciseHasWork);

  /// Drops sessions that were saved with nothing filled in. They are not
  /// training: counted, they would pad workout totals, keep streaks alive and
  /// drag every per-session average toward zero.
  static List<WorkoutSession> loggedSessions(List<WorkoutSession> sessions) =>
      sessions.where(hasWork).toList(growable: false);

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
        if (isWeightedSet(s) && s.weight > top) top = s.weight;
      }
    }
    return top;
  }

  // --- Calendar --------------------------------------------------------------

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Local midnight [days] calendar days from [d].
  ///
  /// Calendar arithmetic, never `Duration`: across a daylight-saving change a
  /// `Duration(days: 7)` step lands on 23:00 or 01:00, and every lookup keyed
  /// on local midnight — streak weeks, chart buckets, the seven-day strip —
  /// quietly misses.
  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Whole calendar days from [from] to [to], ignoring the time of day.
  static int daysBetween(DateTime from, DateTime to) =>
      (dayOf(to).difference(dayOf(from)).inHours / 24).round();

  /// Monday-based start of the week containing [d].
  static DateTime weekStart(DateTime d) => addDays(d, -(d.weekday - 1));

  static DateTime? _earliest(List<WorkoutSession> sessions) {
    DateTime? first;
    for (final s in sessions) {
      if (first == null || s.date.isBefore(first)) first = s.date;
    }
    return first;
  }

  /// How many weeks of training [range] really covers: its length in days,
  /// starting no earlier than the first session, divided by seven — and never
  /// less than one week.
  ///
  /// This is the divisor behind every "per week" figure. Dividing by the full
  /// window instead tells someone three weeks into lifting that they average
  /// a third less than they do.
  static double weeksCovered(List<WorkoutSession> sessions, DateRange range) {
    var start = dayOf(range.start);
    final first = _earliest(sessions);
    if (first != null && dayOf(first).isAfter(start)) start = dayOf(first);
    final days = daysBetween(start, range.end) + 1;
    return math.max(1.0, days / 7.0);
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

  /// Percentage change from [before] to [now]. Growing from nothing counts as
  /// +100% rather than infinity; callers that cannot make sense of that should
  /// check for a zero baseline first.
  static double percentChange(num now, num before) {
    if (before == 0) return now == 0 ? 0 : 100;
    return ((now - before) / before) * 100;
  }

  // --- Time series -----------------------------------------------------------

  /// Volume bucketed per week, oldest first. Weeks with no training are
  /// included as zeros so the chart shows the gaps honestly.
  static List<TimeBucket> weeklyVolume(
    List<WorkoutSession> sessions, {
    int weeks = 12,
    DateTime? now,
  }) {
    final thisWeek = weekStart(now ?? DateTime.now());
    final buckets = <TimeBucket>[];

    for (var i = weeks - 1; i >= 0; i--) {
      final start = addDays(thisWeek, -7 * i);
      final end = addDays(start, 7);

      var volume = 0.0;
      var sets = 0;
      var count = 0;
      for (final s in sessions) {
        if (s.date.isBefore(start) || !s.date.isBefore(end)) continue;
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

    final counts = <DateTime, int>{};
    for (final s in sessions) {
      final w = weekStart(s.date);
      counts[w] = (counts[w] ?? 0) + 1;
    }

    final thisWeek = weekStart(now ?? DateTime.now());
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
      cursor = addDays(cursor, -7);
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
      walk = addDays(walk, 7);
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
    final today = dayOf(now ?? DateTime.now());
    final trained = sessions.map((s) => dayOf(s.date)).toSet();
    return [
      for (var i = 6; i >= 0; i--) trained.contains(addDays(today, -i)),
    ];
  }

  /// Average sessions per week over the trailing [weeks] weeks, as a rolling
  /// window of days ending today (see [weeksCovered] for the divisor).
  static double weeklyFrequency(
    List<WorkoutSession> sessions, {
    int weeks = 8,
    DateTime? now,
  }) {
    if (sessions.isEmpty) return 0;
    final range = DateRange.lastDays(7 * weeks, now: now);
    return sessionsIn(sessions, range).length / weeksCovered(sessions, range);
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

  /// Every exercise with at least one working set in the history, sorted by
  /// how recently it was trained (most recent first) — a far more useful order
  /// for pickers than alphabetical. Skipped exercises do not count as trained.
  static List<String> exerciseNamesByRecency(List<WorkoutSession> sessions) {
    final lastSeen = <String, DateTime>{};
    for (final s in sessions) {
      for (final ex in s.completedExercises) {
        if (!exerciseHasWork(ex)) continue;
        final prev = lastSeen[ex.name];
        if (prev == null || s.date.isAfter(prev)) lastSeen[ex.name] = s.date;
      }
    }
    final names = lastSeen.keys.toList();
    names.sort((a, b) => lastSeen[b]!.compareTo(lastSeen[a]!));
    return names;
  }

  /// One session's worth of an exercise, or null when none of [sets] was done.
  static ExercisePoint? _point(
    WorkoutSession session,
    Iterable<CompletedSet> sets,
    OneRMFormula formula,
  ) {
    var count = 0;
    var reps = 0;
    var bestReps = 0;
    var topWeight = 0.0;
    var topReps = 0;
    var bestOneRm = 0.0;
    var volume = 0.0;

    for (final s in sets) {
      if (!isWorkingSet(s)) continue;
      count++;
      reps += s.reps;
      volume += setVolume(s);
      if (s.reps > bestReps) bestReps = s.reps;

      if (!isWeightedSet(s)) continue;
      // Ties on weight go to the set with more reps: 100 × 3 then 100 × 5 is
      // a 100 × 5 day.
      if (s.weight > topWeight || (s.weight == topWeight && s.reps > topReps)) {
        topWeight = s.weight;
        topReps = s.reps;
      }
      if (s.reps <= maxOneRmReps) {
        final est = OneRMCalculator.calculate(s.weight, s.reps, formula);
        if (est > bestOneRm) bestOneRm = est;
      }
    }

    if (count == 0) return null;
    return ExercisePoint(
      date: session.date,
      sessionId: session.id,
      programTitle: session.programTitle,
      topWeight: topWeight,
      topWeightReps: topReps,
      estimatedOneRm: bestOneRm,
      volume: volume,
      sets: count,
      reps: reps,
      bestReps: bestReps,
    );
  }

  /// Builds the full progress picture for one exercise: every session it was
  /// actually performed in, the estimated 1RM curve, the trend and plateaus.
  ///
  /// An exercise logged twice in one session is one point, not two on the
  /// same day.
  static ExerciseProgress exerciseProgress(
    List<WorkoutSession> sessions,
    String exerciseName, {
    OneRMFormula formula = OneRMFormula.epley,
  }) {
    final points = <ExercisePoint>[];

    for (final session in sessions) {
      final sets = [
        for (final ex in session.completedExercises)
          if (ex.name == exerciseName) ...ex.sets,
      ];
      final point = _point(session, sets, formula);
      if (point != null) points.add(point);
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return ExerciseProgress(name: exerciseName, points: points);
  }

  /// Progress for every exercise in one pass. Much cheaper than calling
  /// [exerciseProgress] per name when you need the whole library, and gives
  /// exactly the same points.
  static Map<String, ExerciseProgress> allExerciseProgress(
    List<WorkoutSession> sessions, {
    OneRMFormula formula = OneRMFormula.epley,
  }) {
    final byExercise = <String, List<ExercisePoint>>{};

    for (final session in sessions) {
      final setsByName = <String, List<CompletedSet>>{};
      for (final ex in session.completedExercises) {
        setsByName.putIfAbsent(ex.name, () => []).addAll(ex.sets);
      }
      setsByName.forEach((name, sets) {
        final point = _point(session, sets, formula);
        if (point != null) byExercise.putIfAbsent(name, () => []).add(point);
      });
    }

    return {
      for (final entry in byExercise.entries)
        entry.key: ExerciseProgress(
          name: entry.key,
          points: entry.value..sort((a, b) => a.date.compareTo(b.date)),
        ),
    };
  }

  /// Least-squares slope of [ys] against [xs], i.e. change per unit of x.
  /// With x in days, multiply by 7 for "per week".
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

  /// Weekly trend of [value] across [points], from a least-squares fit.
  static double weeklyTrend(
    List<ExercisePoint> points,
    double Function(ExercisePoint point) value,
  ) {
    if (points.length < 2) return 0;
    final origin = points.first.date;
    final xs = [
      for (final p in points) p.date.difference(origin).inHours / 24.0,
    ];
    final ys = [for (final p in points) value(p)];
    return linearSlope(xs, ys) * 7;
  }

  // --- Records ---------------------------------------------------------------

  /// All-time personal records, one per exercise, newest first.
  ///
  /// The record is the heaviest working set (more reps breaking a tie on
  /// weight), dated to the first session it was reached in. An exercise only
  /// ever done at bodyweight gets a rep record instead — most reps in one set —
  /// rather than a meaningless 0 kg best.
  static List<PersonalBest> personalBests(
    List<WorkoutSession> sessions, {
    OneRMFormula formula = OneRMFormula.epley,
  }) {
    final progress = allExerciseProgress(sessions, formula: formula);
    final bests = <PersonalBest>[];

    for (final p in progress.values) {
      if (p.points.isEmpty) continue;
      final weighted = p.weightedPoints;
      final bodyweight = weighted.isEmpty;

      final record = bodyweight
          ? p.points.reduce((a, b) => b.bestReps > a.bestReps ? b : a)
          : weighted.reduce((a, b) {
              final heavier = b.topWeight > a.topWeight ||
                  (b.topWeight == a.topWeight &&
                      b.topWeightReps > a.topWeightReps);
              return heavier ? b : a;
            });

      bests.add(PersonalBest(
        exercise: p.name,
        weight: bodyweight ? 0 : record.topWeight,
        reps: bodyweight ? record.bestReps : record.topWeightReps,
        date: record.date,
        estimatedOneRm: p.bestOneRm,
        bestVolume: p.bestVolume,
        firstPerformed: p.points.first.date,
        lastPerformed: p.points.last.date,
        totalSessions: p.points.length,
      ));
    }

    bests.sort((a, b) => b.date.compareTo(a.date));
    return bests;
  }

  /// Records set inside [since]. A record from the very first session of an
  /// exercise is left out: that is a starting point, not a personal best.
  static List<PersonalBest> recentRecords(
    List<WorkoutSession> sessions, {
    Duration since = const Duration(days: 30),
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(since);
    return personalBests(sessions)
        .where((b) => b.date.isAfter(cutoff) && !b.isDebut)
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

  /// Average weekly sets per muscle group, scored against the user's weekly
  /// set band from [goals] (10–20 by default, the evidence-based hypertrophy
  /// range).
  ///
  /// The window is [range] when given, otherwise the last [weeks] × 7 days.
  /// Either way it is a rolling window of days, not calendar weeks: a
  /// Monday-aligned window counts the current week at full weight and made
  /// every muscle look a quarter short on a Monday.
  static List<MuscleBalance> muscleBalance(
    List<WorkoutSession> sessions,
    Map<String, String> exerciseToMuscle, {
    int weeks = 4,
    DateRange? range,
    DateTime? now,
    List<String> groups = defaultMuscleGroups,
    TrainingGoals goals = const TrainingGoals(),
  }) {
    final window = range ?? DateRange.lastDays(7 * weeks, now: now);
    final span = weeksCovered(sessions, window);

    final totals = muscleGroupSets(
      sessions,
      exerciseToMuscle,
      range: window,
      groups: groups,
    );

    final result = <MuscleBalance>[
      for (final group in groups)
        MuscleBalance(
          group: group,
          setsPerWeek: (totals[group] ?? 0) / span,
          totalSets: totals[group] ?? 0,
          targetMin: goals.setsMin,
          targetMax: goals.setsMax,
        ),
    ];

    result.sort((a, b) => b.setsPerWeek.compareTo(a.setsPerWeek));
    return result;
  }

  /// The muscle groups below the user's weekly floor, furthest below first.
  /// Groups that are trained but short come before groups that are not
  /// trained at all — those are as often a deliberate choice as a gap.
  static List<MuscleBalance> weakestGroups(
    List<MuscleBalance> balance, {
    int limit = 3,
  }) {
    final low = balance.where((m) => m.status == VolumeStatus.low).toList()
      ..sort((a, b) => a.setsPerWeek.compareTo(b.setsPerWeek));
    final untrained = balance.where((m) => m.status == VolumeStatus.none);
    return [...low, ...untrained].take(limit).toList();
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

  /// Short, plain-language observations for the top of the Statistics tab.
  ///
  /// Only things the rest of that page does not already show: a fresh record,
  /// a stalled lift, an unusual week. Streaks and muscle balance have their own
  /// cards, so repeating them here as sentences was noise.
  ///
  /// Sorted by [Insight.priority]. Every entry is a threshold on the user's own
  /// history, and the thresholds are all visible in this method.
  static List<Insight> insights(
    List<WorkoutSession> sessions, {
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final out = <Insight>[];

    if (sessions.isEmpty) return out;

    // 1. Volume: this week so far against the same stretch of the weeks
    //    before it.
    //
    //    The current week is only part-finished, so the earlier weeks are cut
    //    off at today's weekday. Compared against four *complete* weeks, a
    //    single Monday session is always ~75% down.
    final thisWeekStart = weekStart(ref);
    final daysElapsed = ref.weekday; // Mon = 1 … Sun = 7
    final firstWeek = weekStart(_earliest(sessions)!);

    double weekToDate(DateTime start) {
      final end = addDays(start, daysElapsed);
      var total = 0.0;
      for (final s in sessions) {
        if (!s.date.isBefore(start) && s.date.isBefore(end)) {
          total += sessionVolume(s);
        }
      }
      return total;
    }

    // Weeks from before the user's first session are not light weeks, they are
    // no weeks. Averaging them in drags the baseline toward zero.
    final priorWeeks = [
      for (var i = 1; i <= 4; i++) addDays(thisWeekStart, -7 * i)
    ].where((w) => !w.isBefore(firstWeek)).toList();

    if (priorWeeks.length >= 2) {
      final thisWeek = weekToDate(thisWeekStart);
      final priorAvg = priorWeeks.map(weekToDate).reduce((a, b) => a + b) /
          priorWeeks.length;

      if (priorAvg > 0 && thisWeek > 0) {
        final change = ((thisWeek - priorAvg) / priorAvg) * 100;

        if (change >= 15) {
          out.add(Insight(
            kind: InsightKind.positive,
            priority: InsightPriority.volumeClimb,
            title: 'Volume is climbing',
            message: '${change.round()}% above your usual pace for this point '
                'in the week.',
          ));
        } else if (change <= -25) {
          out.add(Insight(
            kind: InsightKind.warning,
            priority: InsightPriority.volumeDrop,
            title: 'Lighter week',
            message: '${change.abs().round()}% below your usual pace for this '
                'point in the week.',
          ));
        }
      }
    }

    // 2. Stalled lifts. [ExerciseProgress.isStalled] already requires enough
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
        message: 'No new estimated 1RM in the last '
            '${ExerciseProgress.stallWindow} sessions.',
      ));
    }

    // 3. Recent PRs.
    final prs =
        recentRecords(sessions, since: const Duration(days: 14), now: ref);
    if (prs.isNotEmpty) {
      final first = prs.first;
      out.add(Insight(
        kind: InsightKind.positive,
        priority: InsightPriority.personalRecord,
        title: prs.length == 1
            ? 'New PR: ${first.exercise}'
            : '${prs.length} new PRs',
        message: prs.length == 1
            ? first.setLabel
            : prs.take(3).map((p) => p.exercise).join(', '),
      ));
    }

    // The rules above run in the order that reads best. What the user sees is
    // ranked instead, because the screen only has room for the first few.
    // `List.sort` is not stable, so ties fall back to the order the rules ran.
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
    return DateRange(
      start.subtract(span),
      start.subtract(const Duration(milliseconds: 1)),
    );
  }

  /// Today plus the [days] − 1 calendar days before it.
  static DateRange lastDays(int days, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    return DateRange(AnalyticsService.addDays(ref, -(days - 1)), ref);
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

  /// What a change is measured against — "vs the previous 30 days". Null for
  /// all time, which has nothing before it.
  String? get comparisonLabel => switch (this) {
        StatsPeriod.week => 'vs previous 7 days',
        StatsPeriod.month => 'vs previous 30 days',
        StatsPeriod.quarter => 'vs previous 90 days',
        StatsPeriod.year => 'vs previous year',
        StatsPeriod.all => null,
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
  double get avgSets => workouts == 0 ? 0 : sets / workouts;
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

  double get workoutsChange =>
      AnalyticsService.percentChange(current.workouts, previous.workouts);
  double get volumeChange =>
      AnalyticsService.percentChange(current.volume, previous.volume);
  double get minutesChange =>
      AnalyticsService.percentChange(current.minutes, previous.minutes);
  double get setsChange =>
      AnalyticsService.percentChange(current.sets, previous.sets);
  bool get hasComparison => previous.workouts > 0;

  /// [change] when there is a real baseline to compare against, otherwise
  /// null — so a badge is hidden rather than reading "+100%" from nothing.
  double? deltaOf(num before, double change) =>
      hasComparison && before > 0 ? change : null;
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

  /// Heaviest weighted set, and its reps. 0 when the session was bodyweight
  /// only.
  final double topWeight;
  final int topWeightReps;

  /// Best estimate from weighted sets of [AnalyticsService.maxOneRmReps] reps
  /// or fewer. 0 when there was none.
  final double estimatedOneRm;

  final double volume;

  /// Working sets, bodyweight included.
  final int sets;
  final int reps;

  /// Most reps in any single working set.
  final int bestReps;

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
    this.bestReps = 0,
  });

  bool get isBodyweight => topWeight <= 0;
}

class ExerciseProgress {
  final String name;
  final List<ExercisePoint> points;

  const ExerciseProgress({required this.name, required this.points});

  bool get isEmpty => points.isEmpty;

  ExercisePoint? get latest => points.isEmpty ? null : points.last;
  ExercisePoint? get first => points.isEmpty ? null : points.first;

  /// Sessions that produced a usable 1RM estimate.
  ///
  /// A session of only bodyweight or only high-rep sets has no estimate at
  /// all, so its `estimatedOneRm` is 0. Left in, every such session would plot
  /// as a dive to zero and count as "no improvement".
  List<ExercisePoint> get ratedPoints =>
      points.where((p) => p.estimatedOneRm > 0).toList(growable: false);

  /// Sessions with at least one weighted set — the only ones a top weight or
  /// tonnage chart should plot.
  List<ExercisePoint> get weightedPoints =>
      points.where((p) => p.topWeight > 0).toList(growable: false);

  /// Never done with added load.
  bool get isBodyweight => points.isNotEmpty && points.every((p) => p.isBodyweight);

  double get bestWeight => points.isEmpty
      ? 0
      : points.map((p) => p.topWeight).reduce(math.max);

  double get bestOneRm => points.isEmpty
      ? 0
      : points.map((p) => p.estimatedOneRm).reduce(math.max);

  double get bestVolume =>
      points.isEmpty ? 0 : points.map((p) => p.volume).reduce(math.max);

  int get bestReps =>
      points.isEmpty ? 0 : points.map((p) => p.bestReps).reduce(math.max);

  /// Change in estimated 1RM per week, from a least-squares fit over every
  /// rated session. Positive means the lift is trending up.
  double get oneRmPerWeek =>
      AnalyticsService.weeklyTrend(ratedPoints, (p) => p.estimatedOneRm);

  /// Percentage gain in estimated 1RM from the first rated session to the
  /// latest.
  double get totalGainPercent {
    final rated = ratedPoints;
    if (rated.length < 2) return 0;
    final start = rated.first.estimatedOneRm;
    return ((rated.last.estimatedOneRm - start) / start) * 100;
  }

  /// How many trailing sessions are checked for a new best. The UI quotes this
  /// number, so it lives here rather than as prose in three places.
  static const int stallWindow = 4;

  /// A session has to clear the old peak by this much to count as progress.
  /// Half a percent absorbs rounding in the estimate instead of reading it as a
  /// real improvement.
  static const double stallTolerance = 1.005;

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

  /// Estimated 1RM per rated session, oldest first. Lines up with
  /// [ratedPoints], not with [points].
  List<double> get oneRmSeries =>
      ratedPoints.map((p) => p.estimatedOneRm).toList(growable: false);
}

class PersonalBest {
  final String exercise;

  /// The record set. Weight 0 means a bodyweight-only exercise, whose record
  /// is [reps] in a single set.
  final double weight;
  final int reps;

  /// The first session the record was reached in.
  final DateTime date;

  final double estimatedOneRm;
  final double bestVolume;
  final DateTime firstPerformed;
  final DateTime lastPerformed;
  final int totalSessions;

  const PersonalBest({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.date,
    required this.estimatedOneRm,
    required this.bestVolume,
    required this.firstPerformed,
    required this.lastPerformed,
    required this.totalSessions,
  });

  bool get isBodyweight => weight <= 0;

  /// Set in the exercise's very first session — a baseline, not a beaten best.
  bool get isDebut => !firstPerformed.isBefore(date);

  /// "100 kg × 5", or "12 reps" for a bodyweight record.
  String get setLabel {
    if (isBodyweight) return '$reps ${reps == 1 ? 'rep' : 'reps'}';
    final kg = weight == weight.roundToDouble()
        ? weight.toStringAsFixed(0)
        : weight.toStringAsFixed(1);
    return '$kg kg × $reps';
  }
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

  /// Sets a week still needed to reach the bottom of the band, rounded up.
  int get setsToTarget =>
      math.max(0, (targetMin - setsPerWeek).ceil());

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
abstract final class InsightPriority {
  static const int personalRecord = 100;
  static const int plateau = 90;
  static const int volumeDrop = 70;
  static const int volumeClimb = 60;

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
