import '../models/workout_session_model.dart';
import 'placeholder_history.dart';

/// How one exercise went compared with the last time it was done — worse as
/// well as better, so a lighter day is not silently dressed up as a win.
class ExerciseChange {
  final String exercise;

  /// Working sets logged now minus last time.
  final int setDelta;

  /// Heaviest working set now minus last time (0 for bodyweight vs
  /// bodyweight).
  final double weightDelta;

  /// Only when the top weight is unchanged: reps gained or lost, set by set
  /// at the same weight.
  final int repDelta;

  /// Done last time, nothing logged this time.
  final bool skipped;

  const ExerciseChange({
    required this.exercise,
    this.setDelta = 0,
    this.weightDelta = 0,
    this.repDelta = 0,
    this.skipped = false,
  });

  bool get isEmpty =>
      !skipped && setDelta == 0 && weightDelta == 0 && repDelta == 0;
}

class SessionComparison {
  /// Working sets logged now minus the previous session of the same program;
  /// null when this program has no earlier session.
  final int? setDelta;

  /// Exercises that changed, in workout order.
  final List<ExerciseChange> exercises;

  const SessionComparison({required this.setDelta, required this.exercises});

  int get improvements => exercises
      .where((c) => !c.skipped && (c.weightDelta > 0 || c.repDelta > 0))
      .length;

  int get drops => exercises
      .where((c) => c.skipped || c.weightDelta < 0 || c.repDelta < 0)
      .length;
}

/// Compares [session] with [history]. Each exercise is measured against the
/// most recent time it was logged — same program first, then any program,
/// the same order the in-workout hints use — so the summary agrees with the
/// grey numbers the user was looking at.
SessionComparison compareWithHistory({
  required WorkoutSession session,
  required List<WorkoutSession> history,
}) {
  final previous = history
      .where((s) => s.programTitle == session.programTitle)
      .where((s) => s.completedExercises.any(
            (e) => _workingLogged(e).isNotEmpty,
          ))
      .fold<WorkoutSession?>(
        null,
        (latest, s) => latest == null || s.date.isAfter(latest.date) ? s : latest,
      );

  int total(WorkoutSession s) => s.completedExercises
      .fold(0, (sum, e) => sum + _workingLogged(e).length);

  final changes = <ExerciseChange>[];
  final seen = <String>{};
  for (final exercise in session.completedExercises) {
    if (!seen.add(exercise.name)) continue;
    final before = findPreviousExercise(
      exerciseName: exercise.name,
      history: history,
      programTitle: session.programTitle,
    );
    if (before == null) continue;

    final change = _compare(exercise, before);
    if (!change.isEmpty) changes.add(change);
  }

  return SessionComparison(
    setDelta: previous == null ? null : total(session) - total(previous),
    exercises: changes,
  );
}

ExerciseChange _compare(CompletedExercise now, CompletedExercise before) {
  final nowSets = _workingLogged(now);
  final beforeSets = _workingLogged(before);

  if (nowSets.isEmpty) {
    return ExerciseChange(
      exercise: now.name,
      setDelta: -beforeSets.length,
      skipped: true,
    );
  }

  final weightDelta = _round(_topWeight(nowSets) - _topWeight(beforeSets));

  var repDelta = 0;
  if (weightDelta == 0) {
    final matched =
        nowSets.length < beforeSets.length ? nowSets.length : beforeSets.length;
    for (var i = 0; i < matched; i++) {
      if (nowSets[i].weight == beforeSets[i].weight) {
        repDelta += nowSets[i].reps - beforeSets[i].reps;
      }
    }
  }

  return ExerciseChange(
    exercise: now.name,
    setDelta: nowSets.length - beforeSets.length,
    weightDelta: weightDelta,
    repDelta: repDelta,
  );
}

List<CompletedSet> _workingLogged(CompletedExercise exercise) => exercise.sets
    .where((s) => !s.isWarmUp && isSetLogged(s))
    .toList(growable: false);

double _topWeight(List<CompletedSet> sets) =>
    sets.fold(0.0, (top, s) => s.weight > top ? s.weight : top);

double _round(double value) => (value * 100).roundToDouble() / 100;
