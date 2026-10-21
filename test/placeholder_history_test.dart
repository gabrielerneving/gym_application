import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/models/workout_session_model.dart';
import 'package:gym_app/utils/placeholder_history.dart';

CompletedSet _set(double weight, int reps, {bool warmUp = false}) =>
    CompletedSet(weight: weight, reps: reps, isWarmUp: warmUp);

CompletedExercise _empty(String name, int sets, {int warmUps = 0}) =>
    CompletedExercise(
      name: name,
      sets: List.generate(
        sets,
        (i) => CompletedSet(weight: 0, reps: 0, isWarmUp: i < warmUps),
      ),
    );

WorkoutSession _session(
  String title,
  DateTime date,
  List<CompletedExercise> exercises,
) =>
    WorkoutSession(
      id: '$title-${date.toIso8601String()}',
      programTitle: title,
      date: date,
      durationInMinutes: 60,
      completedExercises: exercises,
    );

void main() {
  final monday = DateTime(2026, 10, 12);
  final thursday = DateTime(2026, 10, 15);
  final nextMonday = DateTime(2026, 10, 19);

  test('a skipped exercise falls back to the session before', () {
    final history = [
      // Most recent Push: bench was skipped, its sets left empty.
      _session('Push', nextMonday, [
        CompletedExercise(name: 'Bench Press', sets: [_set(0, 0), _set(0, 0)]),
        CompletedExercise(name: 'Dips', sets: [_set(0, 12)]),
      ]),
      _session('Push', monday, [
        CompletedExercise(
          name: 'Bench Press',
          sets: [_set(80, 8), _set(80, 6)],
        ),
      ]),
    ];

    final placeholders = buildPlaceholders(
      exercises: [_empty('Bench Press', 2), _empty('Dips', 1)],
      history: history,
      programTitle: 'Push',
    );

    expect(placeholders['w_Bench Press_0'], 80);
    expect(placeholders['r_Bench Press_1'], 6);
    // Bodyweight: reps are borrowed, there is no weight hint.
    expect(placeholders['r_Dips_0'], 12);
    expect(placeholders.containsKey('w_Dips_0'), isFalse);
  });

  test('same program is preferred, other programs are the fallback', () {
    final history = [
      _session('Upper', thursday, [
        CompletedExercise(name: 'Row', sets: [_set(70, 10)]),
        CompletedExercise(name: 'Curl', sets: [_set(15, 12)]),
      ]),
      _session('Pull', monday, [
        CompletedExercise(name: 'Row', sets: [_set(60, 10)]),
      ]),
    ];

    final placeholders = buildPlaceholders(
      exercises: [_empty('Row', 1), _empty('Curl', 1)],
      history: history,
      programTitle: 'Pull',
    );

    expect(placeholders['w_Row_0'], 60);
    expect(placeholders['w_Curl_0'], 15);
  });

  test('working sets line up even when the warm-up count changed', () {
    final history = [
      _session('Legs', monday, [
        CompletedExercise(
          name: 'Squat',
          sets: [_set(60, 5, warmUp: true), _set(100, 5), _set(100, 4)],
        ),
      ]),
    ];

    final placeholders = buildPlaceholders(
      exercises: [_empty('Squat', 4, warmUps: 2)],
      history: history,
      programTitle: 'Legs',
    );

    expect(placeholders['w_Squat_0'], 60);
    expect(placeholders.containsKey('w_Squat_1'), isFalse);
    expect(placeholders['w_Squat_2'], 100);
    expect(placeholders['r_Squat_3'], 4);
  });

  test('a partially logged exercise borrows only the missing sets', () {
    final history = [
      _session('Push', nextMonday, [
        CompletedExercise(
          name: 'Bench Press',
          sets: [_set(85, 8), _set(0, 0), _set(0, 0)],
        ),
      ]),
      _session('Push', monday, [
        CompletedExercise(
          name: 'Bench Press',
          sets: [_set(80, 8), _set(80, 7), _set(80, 6)],
        ),
      ]),
    ];

    final placeholders = buildExercisePlaceholders(
      exercise: _empty('Bench Press', 3),
      history: history,
      programTitle: 'Push',
    );

    expect(placeholders['w_Bench Press_0'], 85);
    expect(placeholders['r_Bench Press_1'], 7);
    expect(placeholders['r_Bench Press_2'], 6);
  });
}
