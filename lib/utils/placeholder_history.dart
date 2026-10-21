import '../models/workout_session_model.dart';

/// Builds the "last time" hints shown in an active workout's empty fields.
///
/// Keys match `workout_provider.dart` and the active workout screen:
/// `w_` / `r_` / `n_` / `rir_` + `<exerciseName>_<setIndex>`.
///
/// Every set looks back through [history] on its own until it finds a set it
/// can borrow, so skipping an exercise (or a set) one session never blanks out
/// the hints for the next one. Sessions of [programTitle] are searched first,
/// newest first, then every other session — which also covers an exercise that
/// was just added to the program or a program that was renamed.
///
/// Warm-up and working sets are matched separately by their position within
/// their own kind: working set 1 borrows from last time's working set 1 even if
/// the number of warm-ups changed in between.
Map<String, dynamic> buildPlaceholders({
  required List<CompletedExercise> exercises,
  required List<WorkoutSession> history,
  String? programTitle,
}) {
  final candidates = _orderCandidates(history, programTitle);
  final placeholders = <String, dynamic>{};

  for (final exercise in exercises) {
    placeholders.addAll(
      _placeholdersFor(exercise, candidates),
    );
  }
  return placeholders;
}

/// The hints for a single exercise — used when an exercise or a set is added
/// to a session that is already running.
Map<String, dynamic> buildExercisePlaceholders({
  required CompletedExercise exercise,
  required List<WorkoutSession> history,
  String? programTitle,
}) {
  return _placeholdersFor(exercise, _orderCandidates(history, programTitle));
}

/// A set counts as logged once it has reps; weight 0 is a bodyweight set.
bool isSetLogged(CompletedSet set) => set.reps > 0;

/// The last time [exerciseName] had a logged working set, searched in the
/// same order as the hints: [programTitle] first, then every other session.
CompletedExercise? findPreviousExercise({
  required String exerciseName,
  required List<WorkoutSession> history,
  String? programTitle,
}) {
  for (final session in _orderCandidates(history, programTitle)) {
    for (final exercise in session.completedExercises) {
      if (exercise.name == exerciseName &&
          exercise.sets.any((s) => !s.isWarmUp && isSetLogged(s))) {
        return exercise;
      }
    }
  }
  return null;
}

List<WorkoutSession> _orderCandidates(
  List<WorkoutSession> history,
  String? programTitle,
) {
  final sorted = List<WorkoutSession>.from(history)
    ..sort((a, b) => b.date.compareTo(a.date));
  if (programTitle == null) return sorted;
  return [
    ...sorted.where((s) => s.programTitle == programTitle),
    ...sorted.where((s) => s.programTitle != programTitle),
  ];
}

Map<String, dynamic> _placeholdersFor(
  CompletedExercise exercise,
  List<WorkoutSession> candidates,
) {
  final placeholders = <String, dynamic>{};
  var warmUpOrdinal = 0;
  var workingOrdinal = 0;

  for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
    final isWarmUp = exercise.sets[setIndex].isWarmUp;
    final ordinal = isWarmUp ? warmUpOrdinal++ : workingOrdinal++;

    final source = _findPreviousSet(
      candidates,
      exercise.name,
      isWarmUp: isWarmUp,
      ordinal: ordinal,
    );
    if (source == null) continue;

    final keyBase = '${exercise.name}_$setIndex';
    if (source.weight > 0) placeholders['w_$keyBase'] = source.weight;
    if (source.reps > 0) placeholders['r_$keyBase'] = source.reps;
    if (source.notes != null && source.notes!.isNotEmpty) {
      placeholders['n_$keyBase'] = source.notes;
    }
    if (source.rir != null && source.rir! > 0) {
      placeholders['rir_$keyBase'] = source.rir;
    }
  }
  return placeholders;
}

CompletedSet? _findPreviousSet(
  List<WorkoutSession> candidates,
  String exerciseName, {
  required bool isWarmUp,
  required int ordinal,
}) {
  for (final session in candidates) {
    for (final previous in session.completedExercises) {
      if (previous.name != exerciseName) continue;
      final sameKind =
          previous.sets.where((s) => s.isWarmUp == isWarmUp).toList();
      if (ordinal < sameKind.length && isSetLogged(sameKind[ordinal])) {
        return sameKind[ordinal];
      }
    }
  }
  return null;
}
