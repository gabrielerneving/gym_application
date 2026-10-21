// Realistic, deterministic fake data for the screenshot tests: four programs,
// a muscle-mapped exercise library, ~8 weeks of progressive history and a
// live "Push Day" session that is half-way through.

import 'dart:math' as math;

import 'package:gym_app/models/workout_session_model.dart';
import 'package:gym_app/providers/rest_timer_provider.dart';
import 'package:gym_app/providers/workout_provider.dart';
import 'package:gym_app/services/database_service.dart';
import 'package:gym_app/utils/placeholder_history.dart';

import 'fake_firebase.dart';

const String demoUid = 'demo-user';
const String demoEmail = 'alex.lindqvist@gmail.com';
const String demoName = 'Alex';

/// One exercise slot in a program, plus how its numbers evolve over the
/// eight weeks of history.
class _Slot {
  final String name;
  final String category;
  final int warmUps;
  final int working;

  /// Warm-up sets as (weight, reps).
  final List<(double, int)> warmUpScheme;

  /// Working weight in the most recent week, and how much lighter it was per
  /// week before that.
  final double latestWeight;
  final double weeklyStep;
  final double rounding;

  /// Reps per working set in the most recent week.
  final List<int> latestReps;

  /// A note left on a working set the last time (index into working sets).
  final ({int set, String text})? note;

  const _Slot(
    this.name,
    this.category, {
    this.warmUps = 0,
    this.working = 3,
    this.warmUpScheme = const [],
    required this.latestWeight,
    required this.weeklyStep,
    this.rounding = 2.5,
    required this.latestReps,
    this.note,
  });
}

class _Program {
  final String id;
  final String title;
  final List<_Slot> slots;
  const _Program(this.id, this.title, this.slots);
}

const _push = _Program('push-day', 'Push Day', [
  _Slot('Bench Press', 'Chest',
      warmUps: 2,
      warmUpScheme: [(40, 10), (60, 5)],
      latestWeight: 80,
      weeklyStep: 2.5,
      latestReps: [8, 8, 7]),
  _Slot('Incline Dumbbell Press', 'Chest',
      latestWeight: 30, weeklyStep: 1, rounding: 2, latestReps: [9, 9, 8]),
  _Slot('Overhead Press', 'Shoulders',
      warmUps: 1,
      warmUpScheme: [(30, 8)],
      latestWeight: 50,
      weeklyStep: 1.25,
      latestReps: [7, 7, 6],
      note: (set: 0, text: 'Strict — no leg drive')),
  _Slot('Lateral Raise', 'Shoulders',
      latestWeight: 12, weeklyStep: 0.5, rounding: 1, latestReps: [15, 14, 12]),
]);

const _pull = _Program('pull-day', 'Pull Day', [
  _Slot('Pull-Up', 'Back',
      latestWeight: 10, weeklyStep: 1.25, latestReps: [8, 7, 6]),
  _Slot('Barbell Row', 'Back',
      warmUps: 1,
      warmUpScheme: [(50, 8)],
      latestWeight: 75,
      weeklyStep: 2.5,
      latestReps: [8, 8, 8]),
  _Slot('Lat Pulldown', 'Back',
      latestWeight: 65, weeklyStep: 2.5, latestReps: [10, 10, 9]),
  _Slot('Face Pull', 'Shoulders',
      latestWeight: 25, weeklyStep: 1.25, latestReps: [15, 15, 15]),
  _Slot('Hammer Curl', 'Biceps',
      latestWeight: 16, weeklyStep: 0.5, rounding: 2, latestReps: [12, 11, 10]),
]);

const _legs = _Program('leg-day', 'Leg Day', [
  _Slot('Back Squat', 'Quads',
      warmUps: 2,
      warmUpScheme: [(60, 8), (90, 3)],
      latestWeight: 110,
      weeklyStep: 2.5,
      latestReps: [6, 6, 5],
      note: (set: 2, text: 'Belt on, depth good')),
  _Slot('Romanian Deadlift', 'Hamstrings',
      warmUps: 1,
      warmUpScheme: [(60, 8)],
      latestWeight: 100,
      weeklyStep: 2.5,
      latestReps: [8, 8, 8]),
  _Slot('Leg Press', 'Quads',
      latestWeight: 200, weeklyStep: 5, rounding: 5, latestReps: [12, 12, 10]),
  _Slot('Lying Leg Curl', 'Hamstrings',
      latestWeight: 45, weeklyStep: 1.25, latestReps: [12, 11, 10]),
  _Slot('Standing Calf Raise', 'Calves',
      working: 4,
      latestWeight: 80,
      weeklyStep: 2.5,
      latestReps: [15, 15, 14, 12]),
]);

const _upper = _Program('upper-body', 'Upper Body', [
  _Slot('Bench Press', 'Chest',
      warmUps: 1,
      warmUpScheme: [(50, 8)],
      latestWeight: 75,
      weeklyStep: 2.5,
      latestReps: [10, 9, 9]),
  _Slot('Barbell Row', 'Back',
      latestWeight: 70, weeklyStep: 2.5, latestReps: [10, 10, 9]),
  _Slot('Dumbbell Shoulder Press', 'Shoulders',
      latestWeight: 24, weeklyStep: 1, rounding: 2, latestReps: [10, 9, 8]),
  _Slot('Triceps Pushdown', 'Triceps',
      latestWeight: 32.5, weeklyStep: 1.25, latestReps: [12, 12, 11]),
  _Slot('Barbell Curl', 'Biceps',
      latestWeight: 35, weeklyStep: 1.25, latestReps: [10, 10, 8]),
  _Slot('Cable Crunch', 'Abs',
      latestWeight: 40, weeklyStep: 2.5, latestReps: [15, 15, 12]),
]);

const List<_Program> _programs = [_push, _pull, _legs, _upper];

double _round(double value, double step) =>
    (value / step).round() * step;

DateTime _day(int daysAgo, {int hour = 17, int minute = 30}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
}

/// Every session in the fake history, newest first.
///
/// Eight weeks of Push / Pull / Legs (two days apart) plus an Upper Body day
/// every other week, with one mostly missed week for texture. The newest week
/// uses exactly the `latest*` numbers above, so the live session's hints and
/// deltas are predictable.
final List<WorkoutSession> demoHistory = _buildHistory();

List<WorkoutSession> _buildHistory() {
  final random = math.Random(42);
  final sessions = <WorkoutSession>[];

  for (var week = 0; week < 8; week++) {
    final weeksBack = 7 - week; // 0 = most recent week
    final base = 7 * weeksBack;
    final plan = <(int, _Program)>[
      (base + 5, _push),
      if (week != 3) (base + 3, _pull),
      if (week != 3) (base + 1, _legs),
      if (week.isEven && week != 3) (base + 6, _upper),
    ];

    for (final (daysAgo, program) in plan) {
      final latest = weeksBack == 0;
      final date = _day(
        daysAgo,
        hour: 17 + random.nextInt(3),
        minute: random.nextInt(60),
      );
      final exercises = <CompletedExercise>[];
      for (final slot in program.slots) {
        final sets = <CompletedSet>[
          for (final (w, r) in slot.warmUpScheme)
            CompletedSet(weight: w, reps: r, isWarmUp: true),
        ];
        final weight = _round(
          slot.latestWeight - slot.weeklyStep * weeksBack,
          slot.rounding,
        );
        for (var i = 0; i < slot.working; i++) {
          final reps = latest
              ? slot.latestReps[i]
              : (slot.latestReps[i] + random.nextInt(3) - 1).clamp(4, 20);
          final note = latest && slot.note != null && slot.note!.set == i
              ? slot.note!.text
              : null;
          sets.add(CompletedSet(weight: weight, reps: reps, notes: note));
        }
        exercises.add(CompletedExercise(name: slot.name, sets: sets));
      }
      sessions.add(
        WorkoutSession(
          id: '${program.id}_${date.millisecondsSinceEpoch}',
          programTitle: program.title,
          date: date,
          durationInMinutes: 48 + random.nextInt(28),
          completedExercises: exercises,
        ),
      );
    }
  }

  // Stamp each set with its progression vs the sessions before it, the way
  // `WorkoutStateNotifier.finishWorkout` does when a real session is saved.
  sessions.sort((a, b) => a.date.compareTo(b.date));
  final stamped = <WorkoutSession>[];
  for (final session in sessions) {
    final hints = buildPlaceholders(
      exercises: session.completedExercises,
      history: stamped,
      programTitle: session.programTitle,
    );
    stamped.add(
      session.copyWith(
        completedExercises: [
          for (final exercise in session.completedExercises)
            exercise.copyWith(
              sets: [
                for (var i = 0; i < exercise.sets.length; i++)
                  _withProgression(
                    exercise.sets[i],
                    hints,
                    '${exercise.name}_$i',
                  ),
              ],
            ),
        ],
      ),
    );
  }

  return stamped.reversed.toList();
}

/// Mirrors `WorkoutStateNotifier._progressionAgainstPlaceholders`.
CompletedSet _withProgression(
  CompletedSet set,
  Map<String, dynamic> hints,
  String keyBase,
) {
  if (set.isWarmUp) return set;
  final previousReps = hints['r_$keyBase'];
  if (previousReps is! num) return set;
  final hintWeight = hints['w_$keyBase'];
  final previousWeight = hintWeight is num ? hintWeight.toDouble() : 0.0;

  int? reps;
  double? weight;
  if (set.weight == previousWeight && set.reps > 0) {
    final d = set.reps - previousReps.toInt();
    if (d != 0) reps = d;
  }
  if (set.weight > 0) {
    final d = set.weight - previousWeight;
    if (d != 0) weight = d;
  }
  return set.copyWith(progression: reps, weightProgression: weight);
}

/// Writes programs, the exercise library, history and the standard templates
/// into [store].
void seedDemoData(FakeFirestore store) {
  final user = 'users/$demoUid';
  store.seed(user, {'email': demoEmail});

  for (final program in _programs) {
    store.seed('$user/workout_programs/${program.id}', {
      'id': program.id,
      'title': program.title,
      'exercises': [
        for (final slot in program.slots)
          {
            'id': '${program.id}-${slot.name.toLowerCase().replaceAll(' ', '-')}',
            'name': slot.name,
            'sets': slot.warmUps + slot.working,
            'workingSets': slot.working,
            'warmUpSets': slot.warmUps,
          },
      ],
    });
  }

  final library = <String, String>{
    for (final program in _programs)
      for (final slot in program.slots) slot.name: slot.category,
    'Deadlift': 'Back',
    'Hip Thrust': 'Glutes',
    'Dips': 'Triceps',
    'Plank': 'Abs',
  };
  var i = 0;
  for (final entry in library.entries) {
    final id = 'ex-${i++}';
    store.seed('$user/master_exercises/$id', {
      'id': id,
      'name': entry.key,
      'category': entry.value,
    });
  }

  for (final session in demoHistory) {
    store.seed('$user/workout_sessions/${session.id}', session.toMap());
  }

  final templates = [
    ('ppl-beginner', 'Push Pull Legs', 'Beginner', 'Push Pull Legs', 60,
        'A classic three-day split. Each muscle once a week, plenty of rest.'),
    ('upper-lower', 'Upper / Lower', 'Intermediate', 'Upper Lower', 70,
        'Four days, each muscle twice a week with heavy and light days.'),
    ('full-body-3', 'Full Body 3×', 'Beginner', 'Full Body', 50,
        'Three short full-body sessions. Great when time is tight.'),
  ];
  for (final (id, title, level, type, minutes, description) in templates) {
    store.seed('standard_workouts/$id', {
      'id': id,
      'title': title,
      'description': description,
      'category': level,
      'type': type,
      'estimatedDurationMinutes': minutes,
      'createdBy': 'Official',
      'exercises': [
        for (final name in ['Bench Press', 'Back Squat', 'Barbell Row'])
          {
            'name': name,
            'sets': 4,
            'workingSets': 3,
            'warmUpSets': 1,
            'muscleGroups': <String>[],
          },
      ],
    });
  }
}

// ---------------------------------------------------------------------------
// The live session
// ---------------------------------------------------------------------------

/// "Push Day", 38 minutes in: warm-ups done, some working sets logged (with
/// deltas both ways), the rest still showing last session's grey hints.
ActiveWorkoutState demoActiveWorkout({int elapsedSeconds = 38 * 60 + 12}) {
  CompletedSet warm(double w, int r) =>
      CompletedSet(weight: w, reps: r, isWarmUp: true);
  CompletedSet work(double w, int r, {String? notes}) =>
      CompletedSet(weight: w, reps: r, notes: notes);
  CompletedSet emptyWarm() => CompletedSet(weight: 0, reps: 0, isWarmUp: true);
  CompletedSet empty() => CompletedSet(weight: 0, reps: 0);

  final exercises = [
    CompletedExercise(name: 'Bench Press', sets: [
      warm(40, 10),
      warm(60, 5),
      work(82.5, 8, notes: 'Paused the first rep'), // +2.5 kg
      work(77.5, 8), // −2.5 kg
      empty(),
    ]),
    CompletedExercise(name: 'Incline Dumbbell Press', sets: [
      work(30, 10), // +1 rep
      work(30, 8), // −1 rep
      empty(),
    ]),
    CompletedExercise(name: 'Overhead Press', sets: [
      emptyWarm(),
      empty(),
      empty(),
      empty(),
    ]),
    CompletedExercise(name: 'Lateral Raise', sets: [
      empty(),
      empty(),
      empty(),
    ]),
  ];

  final edited = <String>{
    for (final key in [
      'Bench Press_0',
      'Bench Press_1',
      'Bench Press_2',
      'Bench Press_3',
      'Incline Dumbbell Press_0',
      'Incline Dumbbell Press_1',
    ]) ...['w_$key', 'r_$key'],
    'n_Bench Press_2',
  };

  final start = DateTime.now().subtract(Duration(seconds: elapsedSeconds));
  return ActiveWorkoutState(
    session: WorkoutSession(
      id: _push.id,
      programTitle: _push.title,
      date: start,
      durationInMinutes: elapsedSeconds ~/ 60,
      completedExercises: exercises,
    ),
    isRunning: true,
    elapsedSeconds: elapsedSeconds,
    startTime: start,
    editedFields: edited,
    placeholders: buildPlaceholders(
      exercises: exercises,
      history: demoHistory,
      programTitle: _push.title,
    ),
  );
}

/// A [WorkoutStateNotifier] whose state is set directly — no timer, no
/// Firestore restore, no `startWorkout`.
class DemoWorkoutNotifier extends WorkoutStateNotifier {
  DemoWorkoutNotifier(ActiveWorkoutState initial)
      : super(DatabaseService(uid: demoUid)) {
    state = initial;
  }

  /// Nothing to restore — the state above is the session.
  @override
  Future<void> loadInitialState() async {}
}

/// A rest that started [elapsed] seconds ago, frozen (no ticker).
class DemoRestTimerNotifier extends RestTimerNotifier {
  DemoRestTimerNotifier({int elapsed = 74, int target = 120}) : super() {
    state = RestTimerState(
      startedAt: DateTime.now().subtract(Duration(seconds: elapsed)),
      elapsedSeconds: elapsed,
      targetSeconds: target,
    );
  }
}
