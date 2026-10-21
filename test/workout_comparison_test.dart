import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/models/workout_session_model.dart';
import 'package:gym_app/utils/workout_comparison.dart';

CompletedSet _set(double weight, int reps, {bool warmUp = false}) =>
    CompletedSet(weight: weight, reps: reps, isWarmUp: warmUp);

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
  final lastWeek = DateTime(2026, 10, 14);
  final today = DateTime(2026, 10, 21);

  test('fewer sets, fewer reps and a skipped exercise all show as drops', () {
    final history = [
      _session('Push', lastWeek, [
        CompletedExercise(
          name: 'Bench Press',
          sets: [_set(40, 10, warmUp: true), _set(80, 8), _set(80, 8), _set(80, 7)],
        ),
        CompletedExercise(name: 'Dips', sets: [_set(0, 12), _set(0, 10)]),
        CompletedExercise(name: 'Fly', sets: [_set(15, 12)]),
      ]),
    ];
    final session = _session('Push', today, [
      CompletedExercise(
        name: 'Bench Press',
        sets: [_set(40, 10, warmUp: true), _set(80, 8), _set(80, 6), _set(0, 0)],
      ),
      CompletedExercise(name: 'Dips', sets: [_set(0, 13), _set(0, 10)]),
      CompletedExercise(name: 'Fly', sets: [_set(0, 0)]),
    ]);

    final result = compareWithHistory(session: session, history: history);

    expect(result.setDelta, -2);
    final bench = result.exercises.firstWhere((c) => c.exercise == 'Bench Press');
    expect(bench.setDelta, -1);
    expect(bench.weightDelta, 0);
    expect(bench.repDelta, -2);
    final dips = result.exercises.firstWhere((c) => c.exercise == 'Dips');
    expect(dips.repDelta, 1);
    final fly = result.exercises.firstWhere((c) => c.exercise == 'Fly');
    expect(fly.skipped, isTrue);
    expect(fly.setDelta, -1);
    expect(result.improvements, 1);
    expect(result.drops, 2);
  });

  test('a heavier top set reports weight, not the reps it cost', () {
    final history = [
      _session('Legs', lastWeek, [
        CompletedExercise(name: 'Squat', sets: [_set(100, 5), _set(100, 5)]),
      ]),
    ];
    final session = _session('Legs', today, [
      CompletedExercise(name: 'Squat', sets: [_set(105, 3), _set(100, 5)]),
    ]);

    final result = compareWithHistory(session: session, history: history);
    final squat = result.exercises.single;

    expect(squat.weightDelta, 5);
    expect(squat.repDelta, 0);
    expect(squat.setDelta, 0);
  });

  test('a program with no earlier session has no total, unchanged lifts are left out', () {
    final history = [
      _session('Upper', lastWeek, [
        CompletedExercise(name: 'Row', sets: [_set(60, 10)]),
      ]),
    ];
    final session = _session('Pull', today, [
      CompletedExercise(name: 'Row', sets: [_set(60, 10)]),
      CompletedExercise(name: 'Curl', sets: [_set(12, 12)]),
    ]);

    final result = compareWithHistory(session: session, history: history);

    expect(result.setDelta, isNull);
    expect(result.exercises, isEmpty);
  });
}
