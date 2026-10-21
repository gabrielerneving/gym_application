import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session_model.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import 'training_goals_provider.dart';

/// ---------------------------------------------------------------------------
/// Analytics wiring.
///
/// The whole statistics side of the app reads from ONE Firestore fetch of the
/// session history, cached here. Individual screens then derive whatever they
/// need with [AnalyticsService], which is pure and cheap.
///
/// Before this, each stats page called a different `DatabaseService` helper and
/// several of those helpers re-read the entire `workout_sessions` collection
/// once *per exercise* — opening the 1RM screen with 40 exercises in the
/// history meant 40 full collection reads. Now it is one.
///
/// Call `ref.invalidate(workoutSessionsProvider)` after finishing a workout to
/// refresh everything downstream.
/// ---------------------------------------------------------------------------

/// The signed-in user's uid, or null when logged out.
final currentUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

final databaseServiceProvider = Provider<DatabaseService?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return DatabaseService(uid: uid);
});

/// Every completed session, newest first. The single source for all stats.
final workoutSessionsProvider =
    FutureProvider<List<WorkoutSession>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return const [];
  return db.getAllWorkoutSessions();
});

/// Exercise name → muscle group, from the user's master exercise library.
///
/// A live stream rather than a one-off fetch: a newly created exercise or a
/// changed category lands in the statistics straight away instead of after
/// the next app restart.
final exerciseMuscleMapProvider =
    StreamProvider<Map<String, String>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return Stream.value(const {});
  return db.watchExerciseToMuscleGroupMap();
});

/// Everything the statistics screens need, resolved together.
///
/// Watching the goals here is what makes them take effect everywhere at once:
/// editing the weekly set band rebuilds this from the *cached* session list, so
/// every screen re-scores instantly without a single extra Firestore read.
final trainingDataProvider = FutureProvider<TrainingData>((ref) async {
  final goals = ref.watch(trainingGoalsProvider);
  final sessions = await ref.watch(workoutSessionsProvider.future);
  // The muscle map only labels exercises; a failed listener (it stays failed —
  // a Firestore stream ends on error) should not blank every stats screen.
  Map<String, String> muscleMap;
  try {
    muscleMap = await ref.watch(exerciseMuscleMapProvider.future);
  } catch (_) {
    muscleMap = const {};
  }
  return TrainingData(
    sessions: sessions,
    exerciseToMuscle: muscleMap,
    goals: goals,
  );
});

/// The period currently selected on the statistics screens. Shared so moving
/// between stats pages keeps the same window.
final statsPeriodProvider = StateProvider<StatsPeriod>((ref) {
  return StatsPeriod.month;
});

/// A snapshot of the user's training history plus the exercise→muscle mapping,
/// with the common derivations memoised so a rebuild does not recompute them.
class TrainingData {
  /// Every session with at least one working set, newest first.
  ///
  /// Sessions saved with nothing filled in are dropped here, once, so no
  /// screen can count them: not as a workout, not toward a streak, not in an
  /// average.
  final List<WorkoutSession> sessions;
  final Map<String, String> exerciseToMuscle;

  /// The targets everything below is scored against. Screens read this rather
  /// than watching [trainingGoalsProvider] separately, so the numbers on the
  /// chart and the numbers in the caption can never come from different reads.
  final TrainingGoals goals;

  TrainingData({
    required List<WorkoutSession> sessions,
    required this.exerciseToMuscle,
    this.goals = const TrainingGoals(),
  }) : sessions = AnalyticsService.loggedSessions(sessions);

  bool get isEmpty => sessions.isEmpty;

  late final Map<String, ExerciseProgress> exerciseProgress =
      AnalyticsService.allExerciseProgress(sessions);

  late final List<String> exerciseNames =
      AnalyticsService.exerciseNamesByRecency(sessions);

  late final List<PersonalBest> personalBests =
      AnalyticsService.personalBests(sessions);

  late final StreakInfo streak = AnalyticsService.weeklyStreak(
    sessions,
    sessionsPerWeek: goals.sessionsPerWeek,
  );

  late final List<ProgramUsage> programs =
      AnalyticsService.programUsage(sessions);

  late final List<MuscleBalance> muscleBalance =
      AnalyticsService.muscleBalance(sessions, exerciseToMuscle, goals: goals);

  late final List<Insight> insights = AnalyticsService.insights(sessions);

  late final List<TimeBucket> weeklyVolume =
      AnalyticsService.weeklyVolume(sessions, weeks: 12);

  late final List<bool> lastSevenDays =
      AnalyticsService.lastSevenDays(sessions);

  PeriodSummary summaryFor(StatsPeriod period) =>
      AnalyticsService.summarize(sessions, period.range());

  /// The sessions inside [period].
  List<WorkoutSession> sessionsFor(StatsPeriod period) =>
      period == StatsPeriod.all
          ? sessions
          : AnalyticsService.sessionsIn(sessions, period.range());

  /// Weekly sets per muscle group averaged over [period].
  List<MuscleBalance> muscleBalanceFor(StatsPeriod period) =>
      AnalyticsService.muscleBalance(
        sessions,
        exerciseToMuscle,
        range: period.range(),
        goals: goals,
      );

  /// Working sets per muscle group inside [period] — the counts behind
  /// [muscleBalanceFor], including the "Other" bucket for unmapped exercises.
  Map<String, int> muscleSetsFor(StatsPeriod period) =>
      AnalyticsService.muscleGroupSets(
        sessions,
        exerciseToMuscle,
        range: period.range(),
      );

  ExerciseProgress progressFor(String exercise) =>
      exerciseProgress[exercise] ??
      ExerciseProgress(name: exercise, points: const []);
}
