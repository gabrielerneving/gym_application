import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session_model.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';

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
final exerciseMuscleMapProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  if (db == null) return const {};
  return db.getExerciseToMuscleGroupMap();
});

/// Everything the statistics screens need, resolved together.
final trainingDataProvider = FutureProvider<TrainingData>((ref) async {
  final sessions = await ref.watch(workoutSessionsProvider.future);
  final muscleMap = await ref.watch(exerciseMuscleMapProvider.future);
  return TrainingData(sessions: sessions, exerciseToMuscle: muscleMap);
});

/// The period currently selected on the statistics screens. Shared so moving
/// between stats pages keeps the same window.
final statsPeriodProvider = StateProvider<StatsPeriod>((ref) {
  return StatsPeriod.month;
});

/// A snapshot of the user's training history plus the exercise→muscle mapping,
/// with the common derivations memoised so a rebuild does not recompute them.
class TrainingData {
  final List<WorkoutSession> sessions;
  final Map<String, String> exerciseToMuscle;

  TrainingData({required this.sessions, required this.exerciseToMuscle});

  bool get isEmpty => sessions.isEmpty;

  late final Map<String, ExerciseProgress> exerciseProgress =
      AnalyticsService.allExerciseProgress(sessions);

  late final List<String> exerciseNames =
      AnalyticsService.exerciseNamesByRecency(sessions);

  late final List<PersonalBest> personalBests =
      AnalyticsService.personalBests(sessions);

  late final StreakInfo streak = AnalyticsService.weeklyStreak(sessions);

  late final List<ProgramUsage> programs =
      AnalyticsService.programUsage(sessions);

  late final List<MuscleBalance> muscleBalance =
      AnalyticsService.muscleBalance(sessions, exerciseToMuscle);

  late final List<Insight> insights =
      AnalyticsService.insights(sessions, exerciseToMuscle);

  late final List<TimeBucket> weeklyVolume =
      AnalyticsService.weeklyVolume(sessions, weeks: 12);

  late final List<bool> lastSevenDays =
      AnalyticsService.lastSevenDays(sessions);

  PeriodSummary summaryFor(StatsPeriod period) =>
      AnalyticsService.summarize(sessions, period.range());

  ExerciseProgress progressFor(String exercise) =>
      exerciseProgress[exercise] ??
      ExerciseProgress(name: exercise, points: const []);
}
