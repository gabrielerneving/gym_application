import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';
import '../models/workout_session_model.dart';
import '../models/exercise_model.dart';
import '../services/database_service.dart';

// State-objekt för aktivt träningspass (immutable)
class ActiveWorkoutState {
  final WorkoutSession? session;
  final bool isRunning;
  final int elapsedSeconds;
  final DateTime? startTime; // Timestamp när träningen började
  final WorkoutSession? staleSession; // Gamla obesvarade pass
  final Set<String> editedFields; // Spårar redigerade fält
  final Map<String, dynamic> placeholders; // Basvärden från förra passet

  ActiveWorkoutState({
    this.session,
    this.isRunning = false,
    this.elapsedSeconds = 0,
    this.startTime,
    this.staleSession,
    Set<String>? editedFields,
    Map<String, dynamic>? placeholders,
  }) : editedFields = editedFields ?? <String>{},
       placeholders = placeholders ?? <String, dynamic>{};

  // Skapar ny kopia av state med uppdateringar
  ActiveWorkoutState copyWith({
    WorkoutSession? session,
    bool? isRunning,
    int? elapsedSeconds,
    DateTime? startTime,
    WorkoutSession? staleSession,
    bool clearStaleSession = false, // Flagga för att nollställa staleSession
    Set<String>? editedFields,
    Map<String, dynamic>? placeholders,
  }) {
    return ActiveWorkoutState(
      session: session ?? this.session,
      isRunning: isRunning ?? this.isRunning,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      startTime: startTime ?? this.startTime,
      staleSession:
          clearStaleSession ? null : staleSession ?? this.staleSession,
      editedFields: editedFields ?? this.editedFields,
      placeholders: placeholders ?? this.placeholders,
    );
  }
}

// StateNotifier som hanterar träningspass-logik
class WorkoutStateNotifier extends StateNotifier<ActiveWorkoutState> {
  final DatabaseService dbService;
  Timer? _timer;

  WorkoutStateNotifier(this.dbService)
    : super(
        ActiveWorkoutState(
          editedFields: <String>{},
          placeholders: <String, dynamic>{},
        ),
      );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> startWorkout(WorkoutProgram program) async {
    if (state.isRunning) return;

    // STEG 1: Hitta senaste passet av denna typ
    final lastSession = await dbService.findLastSessionOfProgram(program.title);

    // STEG 2: Skapa nytt pass med tomma värden
    final initialExercises =
        program.exercises.map((currentExercise) {
          return CompletedExercise(
            name: currentExercise.name,
            sets: List.generate(currentExercise.sets, (setIndex) {
              // Första sets är warm-up
              final isWarmUpSet = setIndex < currentExercise.warmUpSets;
              return CompletedSet(
                weight: 0,
                reps: 0,
                notes: null,
                isWarmUp: isWarmUpSet,
              );
            }),
          );
        }).toList();

    final newSession = WorkoutSession(
      id: program.id,
      programTitle: program.title,
      date: DateTime.now(),
      durationInMinutes: 0,
      completedExercises: initialExercises,
    );

    // STEG 3: Bygg placeholders från förra passets värden (INTE nuvarande session)
    // VIKTIGT: Använd övningsnamn för stabila nycklar som överlever exercise-reordering
    final Map<String, dynamic> placeholders = <String, dynamic>{};
    if (lastSession != null) {
      for (int exIndex = 0; exIndex < program.exercises.length; exIndex++) {
        final currentExercise = program.exercises[exIndex];

        // Försök hitta en matchande övning i det gamla passet
        final lastExerciseData = lastSession.completedExercises.firstWhere(
          (completedEx) => completedEx.name == currentExercise.name,
          orElse: () => CompletedExercise(name: "", sets: []),
        );

        // Skapa placeholders från förra passets data med STABILA nycklar
        // Format: "exerciseName_w_setNumber" istället för "exIndex_w_setIndex"
        for (int setIndex = 0; setIndex < currentExercise.sets; setIndex++) {
          if (lastExerciseData.sets.isNotEmpty &&
              setIndex < lastExerciseData.sets.length) {
            final lastSet = lastExerciseData.sets[setIndex];
            // Använd övningsnamn och absolut set-nummer för stabilitet
            final keyBase = '${currentExercise.name}_$setIndex';
            
            if (lastSet.weight > 0) {
              placeholders['w_$keyBase'] = lastSet.weight;
            }
            if (lastSet.reps > 0) {
              placeholders['r_$keyBase'] = lastSet.reps;
            }
            if (lastSet.notes != null && lastSet.notes!.isNotEmpty) {
              placeholders['n_$keyBase'] = lastSet.notes;
            }
            if (lastSet.rir != null && lastSet.rir! > 0) {
              placeholders['rir_$keyBase'] = lastSet.rir;
            }
          }
        }
      }
    }

    final startTime = DateTime.now();

    state = ActiveWorkoutState(
      session: newSession,
      isRunning: true,
      elapsedSeconds: 0,
      startTime: startTime,
      editedFields: <String>{},
      placeholders: placeholders,
    );
    // Persistera även placeholders och startTime till Firestore så de överlever app-restart
    unawaited(dbService.saveActivePlaceholders(placeholders));
    unawaited(dbService.saveActiveStartTime(startTime));
    _startTimer();
  }

  void updateSetData(
    int exerciseIndex,
    int setIndex, {
    double? weight,
    int? reps,
    String? notes,
    int? rir,
  }) {
    if (!state.isRunning || state.session == null) return;

    // Använd copyWith för en mycket renare och säkrare uppdatering
    final updatedExercises = List<CompletedExercise>.from(
      state.session!.completedExercises,
    );
    final exerciseToUpdate = updatedExercises[exerciseIndex];
    final updatedSets = List<CompletedSet>.from(exerciseToUpdate.sets);

    // Hämta det nuvarande setet och skapa en uppdaterad version
    final currentSet = updatedSets[setIndex];

    // Beräkna progression direkt när data uppdateras
    int? repProgression;
    double? weightProgression;

    if (!currentSet.isWarmUp) {
      final exerciseName = state.session!.completedExercises[exerciseIndex].name;
      final keyBase = '${exerciseName}_$setIndex';
      final previousWeight = state.placeholders['w_$keyBase'];
      final previousReps = state.placeholders['r_$keyBase'];

      if (previousWeight != null && previousReps != null) {
        final updatedWeight = weight ?? currentSet.weight;
        final updatedReps = reps ?? currentSet.reps;

        // Beräkna rep progression (endast om vikten är samma)
        if (updatedWeight == previousWeight &&
            updatedWeight > 0 &&
            updatedReps > 0) {
          final repsDifference = updatedReps - (previousReps as int);
          if (repsDifference != 0) {
            repProgression = repsDifference;
          }
        }

        // Beräkna vikt progression (alltid när vikten ändras, oavsett reps)
        if (updatedWeight > 0) {
          final weightDifference =
              updatedWeight - (previousWeight as num).toDouble();
          if (weightDifference != 0) {
            weightProgression = weightDifference;
          }
        }
      }
    }

    updatedSets[setIndex] = currentSet.copyWith(
      weight: weight,
      reps: reps,
      notes: notes,
      rir: rir,
      progression: repProgression,
      weightProgression: weightProgression,
    );

    updatedExercises[exerciseIndex] = exerciseToUpdate.copyWith(
      sets: updatedSets,
    );

    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
    );
    _saveStateToFirestore();
  }

  // Markera ett fält som redigerat (anropas från UI när användaren skriver eller swipar)
  void markFieldEdited(String key) {
    final updated = Set<String>.from(state.editedFields)..add(key);
    state = state.copyWith(editedFields: updated);
    // Persist to backend
    unawaited(dbService.saveActiveEditedKeys(updated));
  }

  void markFieldsEdited(Iterable<String> keys) {
    final updated = Set<String>.from(state.editedFields)..addAll(keys);
    state = state.copyWith(editedFields: updated);
    unawaited(dbService.saveActiveEditedKeys(updated));
  }

  void unmarkFieldEdited(String key) {
    if (!state.editedFields.contains(key)) return;
    final updated = Set<String>.from(state.editedFields)..remove(key);
    state = state.copyWith(editedFields: updated);
    unawaited(dbService.saveActiveEditedKeys(updated));
  }

  void clearEditedFields() {
    if (state.editedFields.isEmpty) return;
    state = state.copyWith(editedFields: <String>{});
    unawaited(dbService.saveActiveEditedKeys(<String>{}));
  }

  Future<void> finishWorkout() async {
    if (!state.isRunning || state.session == null) return;
    _timer?.cancel();

    // Beräkna progression för varje set genom att jämföra med placeholders
    final updatedExercises = <CompletedExercise>[];
    for (
      int exerciseIndex = 0;
      exerciseIndex < state.session!.completedExercises.length;
      exerciseIndex++
    ) {
      final exercise = state.session!.completedExercises[exerciseIndex];
      final updatedSets = <CompletedSet>[];

      for (int setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
        final set = exercise.sets[setIndex];
        int? repProgression;
        double? weightProgression;

        // Beräkna progression om setet inte är ett warmup
        if (!set.isWarmUp) {
          final keyBase = '${exercise.name}_$setIndex';
          final previousWeight = state.placeholders['w_$keyBase'];
          final previousReps = state.placeholders['r_$keyBase'];

          if (previousWeight != null && previousReps != null) {
            final currentWeight = set.weight;
            final currentReps = set.reps;

            // Beräkna rep progression (endast om vikten är samma)
            if (currentWeight == previousWeight &&
                currentWeight > 0 &&
                currentReps > 0) {
              final repsDifference = currentReps - (previousReps as int);
              if (repsDifference != 0) {
                repProgression = repsDifference;
              }
            }

            // Beräkna vikt progression (alltid när vikten ändras, oavsett reps)
            if (currentWeight > 0) {
              final weightDifference =
                  currentWeight - (previousWeight as num).toDouble();
              if (weightDifference != 0) {
                weightProgression = weightDifference;
              }
            }
          }
        }

        updatedSets.add(
          set.copyWith(
            progression: repProgression,
            weightProgression: weightProgression,
          ),
        );
      }

      updatedExercises.add(exercise.copyWith(sets: updatedSets));
    }

    final finalSession = state.session!.copyWith(
      id: const Uuid().v4(), // Ge den ett nytt, unikt ID för historiken
      durationInMinutes: (state.elapsedSeconds / 60).ceil(),
      date: DateTime.now(),
      completedExercises: updatedExercises,
    );

    await dbService.saveWorkoutSession(finalSession);
    await dbService.deleteActiveWorkoutState();
    state = ActiveWorkoutState();
  }

  void pauseWorkout() {
    _timer?.cancel();
    if (state.isRunning) {
      _saveStateToFirestore();
    }
  }

  // Force-spara current state (anropas t.ex. när användaren lämnar skärmen)
  void saveCurrentState() {
    if (state.isRunning) {
      _saveStateToFirestore();
    }
  }

  Future<void> loadInitialState() async {
    final session = await dbService.loadActiveWorkoutState();
    final edited = await dbService.loadActiveEditedKeys();
    var placeholders = await dbService.loadActivePlaceholders();
    final savedStartTime = await dbService.loadActiveStartTime();

    if (session != null) {
      // Om placeholders är tomma (kan hända vid app-restart),
      // hämta placeholders från föregående AVSLUTADE pass av samma typ
      if (placeholders.isEmpty) {
        final lastFinishedSession = await dbService.findLastSessionOfProgram(
          session.programTitle,
        );
        if (lastFinishedSession != null) {
          placeholders = _buildPlaceholdersFromSession(lastFinishedSession);
          // Spara dem för framtida användning
          unawaited(dbService.saveActivePlaceholders(placeholders));
        }
      }

      final now = DateTime.now();

      // Använd sparad startTime om den finns, annars fallback till session.date
      final actualStartTime = savedStartTime ?? session.date;
      final actualElapsedTime = now.difference(actualStartTime);

      if (actualElapsedTime.inHours >= 8) {
        state = state.copyWith(
          staleSession: session,
          editedFields: edited,
          placeholders: placeholders,
        );
      } else {
        state = state.copyWith(
          editedFields: edited,
          placeholders: placeholders,
        );
        _resumeWorkout(
          session,
          actualElapsedTime.inSeconds,
          savedStartTime: actualStartTime,
        );
      }
    }
  }

  void discardStaleWorkout() {
    if (state.staleSession == null) return;
    dbService.deleteActiveWorkoutState();
    state = state.copyWith(clearStaleSession: true);
  }

  void resumeStaleWorkout() {
    if (state.staleSession == null) return;
    final session = state.staleSession!;
    final timeSinceSave = DateTime.now().difference(session.date).inSeconds;
    _resumeWorkout(session, timeSinceSave);
  }

  // ----- PRIVATA HJÄLPMETODER -----

  // Hjälpmetod för att bygga placeholders från en session (för återupptag av pågående workout)
  Map<String, dynamic> _buildPlaceholdersFromSession(WorkoutSession session) {
    final Map<String, dynamic> placeholders = <String, dynamic>{};
    for (
      int exIndex = 0;
      exIndex < session.completedExercises.length;
      exIndex++
    ) {
      final ex = session.completedExercises[exIndex];
      for (int setIndex = 0; setIndex < ex.sets.length; setIndex++) {
        final set = ex.sets[setIndex];
        final keyBase = '${ex.name}_$setIndex';
        if (set.weight > 0) placeholders['w_$keyBase'] = set.weight;
        if (set.reps > 0) placeholders['r_$keyBase'] = set.reps;
        if (set.notes != null && set.notes!.isNotEmpty) {
          placeholders['n_$keyBase'] = set.notes;
        }
        if (set.rir != null && set.rir! > 0) {
          placeholders['rir_$keyBase'] = set.rir;
        }
      }
    }
    return placeholders;
  }

  void _resumeWorkout(
    WorkoutSession session,
    int secondsToAdd, {
    DateTime? savedStartTime,
  }) {
    final savedDurationInSeconds = session.durationInMinutes * 60;
    final totalElapsedSeconds = savedDurationInSeconds + secondsToAdd;

    // Kontrollera om träningspasset har pågått för länge redan när vi återupptar (8 timmar = 28800 sekunder)
    if (totalElapsedSeconds >= 28800) {
      debugPrint('Workout exceeded 8 hours, auto-finishing on resume...');
      // Avsluta workoutet automatiskt istället för att återuppta
      dbService.deleteActiveWorkoutState();
      state = state.copyWith(clearStaleSession: true);
      return;
    }

    // Använd sparad startTime om den finns, annars beräkna den
    final actualStartTime =
        savedStartTime ??
        DateTime.now().subtract(Duration(seconds: totalElapsedSeconds));

    // VIKTIGT: Behåll placeholders från nuvarande state när vi skapar nytt state
    state = ActiveWorkoutState(
      session: session,
      isRunning: true,
      elapsedSeconds: totalElapsedSeconds,
      startTime: actualStartTime,
      staleSession: null,
      editedFields:
          state.editedFields.isNotEmpty ? state.editedFields : <String>{},
      placeholders: state.placeholders, // BEHÅLL PLACEHOLDERS!
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Beräkna faktisk tid baserat på timestamp istället för att räkna sekunder
        if (state.startTime != null) {
          final actualElapsedSeconds =
              DateTime.now().difference(state.startTime!).inSeconds;
          state = state.copyWith(elapsedSeconds: actualElapsedSeconds);

          // Kontrollera om träningspasset har pågått för länge (8 timmar = 28800 sekunder)
          if (actualElapsedSeconds >= 28800) {
            debugPrint('Workout has been running for 8 hours, auto-finishing...');
            finishWorkout();
            return;
          }

          // Spara oftare (var 5:e sekund istället för 15:e) för bättre persistens
          if (actualElapsedSeconds % 5 == 0) {
            _saveStateToFirestore();
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _saveStateToFirestore() {
    if (!state.isRunning || state.session == null) return;
    // OBS: Överskriver INTE session.date här — startTime sparas separat.
    // Om vi sätter date: DateTime.now() vid varje save, och startTime saknas vid resume,
    // blir elapsed-tid felberäknad.
    final sessionToSave = state.session!.copyWith(
      durationInMinutes: (state.elapsedSeconds / 60).round(),
    );
    dbService.saveActiveWorkoutState(sessionToSave);
    // Persist edited fields as well
    dbService.saveActiveEditedKeys(state.editedFields);
  }

  void addSet(int exerciseIndex) {
    if (!state.isRunning || state.session == null) return;

    final updatedExercises = List<CompletedExercise>.from(
      state.session!.completedExercises,
    );
    final exercise = updatedExercises[exerciseIndex];

    final newSet = CompletedSet(
      weight: 0,
      reps: 0,
      notes: null,
      isWarmUp: false,
    );

    final updatedSets = List<CompletedSet>.from(exercise.sets)..add(newSet);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
    );
    _saveStateToFirestore();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    if (!state.isRunning || state.session == null) return;

    final updatedExercises = List<CompletedExercise>.from(
      state.session!.completedExercises,
    );
    final exercise = updatedExercises[exerciseIndex];

    if (exercise.sets.length <= 1) return;

    final updatedSets = List<CompletedSet>.from(exercise.sets)
      ..removeAt(setIndex);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

    // Rensa alla placeholders och edited fields för sets efter det borttagna
    // eftersom set-index kommer att shifta
    final newPlaceholders = Map<String, dynamic>.from(state.placeholders);
    final newEditedFields = Set<String>.from(state.editedFields);
    final exerciseName = exercise.name;
    
    // Ta bort placeholders och edited fields för alla sets från det borttagna och uppåt
    for (int idx = setIndex; idx < exercise.sets.length; idx++) {
      for (final prefix in ['w_', 'r_', 'n_', 'rir_']) {
        final key = '$prefix${exerciseName}_$idx';
        newPlaceholders.remove(key);
        newEditedFields.remove(key);
      }
    }

    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
      placeholders: newPlaceholders,
      editedFields: newEditedFields,
    );
    _saveStateToFirestore();
  }

  void addExercise(String exerciseName, {int sets = 3, int warmUpSets = 0}) {
    if (!state.isRunning || state.session == null) return;

    final newSets = <CompletedSet>[];

    // Add warm-up sets
    for (int i = 0; i < warmUpSets; i++) {
      newSets.add(
        CompletedSet(weight: 0, reps: 0, notes: null, isWarmUp: true),
      );
    }

    // Add working sets
    for (int i = 0; i < sets; i++) {
      newSets.add(
        CompletedSet(weight: 0, reps: 0, notes: null, isWarmUp: false),
      );
    }

    final newExercise = CompletedExercise(name: exerciseName, sets: newSets);

    final updatedExercises = List<CompletedExercise>.from(
      state.session!.completedExercises,
    )..add(newExercise);

    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
    );
    _saveStateToFirestore();
  }

  void removeExercise(int exerciseIndex) {
    if (!state.isRunning || state.session == null) return;

    final exerciseToRemove = state.session!.completedExercises[exerciseIndex];
    final updatedExercises = List<CompletedExercise>.from(
      state.session!.completedExercises,
    )..removeAt(exerciseIndex);

    // Ta bort alla placeholders och edited fields för den borttagna övningen
    final newPlaceholders = Map<String, dynamic>.from(state.placeholders);
    final newEditedFields = Set<String>.from(state.editedFields);
    final exerciseName = exerciseToRemove.name;
    
    // Ta bort alla nycklar för denna övning
    // Använd exakt prefix-matching med alla kända prefix för att undvika
    // kollision med övningar som har överlappande namn (t.ex. "Bench Press" vs "Bench Press Close Grip")
    for (int idx = 0; idx < exerciseToRemove.sets.length; idx++) {
      for (final prefix in ['w_', 'r_', 'n_', 'rir_']) {
        final key = '$prefix${exerciseName}_$idx';
        newPlaceholders.remove(key);
        newEditedFields.remove(key);
      }
    }

    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
      placeholders: newPlaceholders,
      editedFields: newEditedFields,
    );
    _saveStateToFirestore();
  }

  Future<void> saveActiveWorkoutAsTemplate(
    String name, {
    bool overwrite = false,
  }) async {
    if (state.session == null) return;

    final session = state.session!;

    final exercises =
        session.completedExercises.map((e) {
          final totalSets = e.sets.length;
          final warmUpSets = e.sets.where((s) => s.isWarmUp).length;
          final workingSets = totalSets - warmUpSets;

          return Exercise(
            id: const Uuid().v4(),
            name: e.name,
            sets: totalSets,
            workingSets: workingSets,
            warmUpSets: warmUpSets,
          );
        }).toList();

    final programId = const Uuid().v4();

    final newProgram = WorkoutProgram(
      id: programId,
      title: name,
      exercises: exercises,
    );

    await dbService.saveWorkoutProgram(newProgram);
  }

  Future<void> updateOriginalTemplate() async {
    if (state.session == null) return;

    final session = state.session!;

    // Convert current exercises to Exercise format
    final exercises =
        session.completedExercises.map((e) {
          final totalSets = e.sets.length;
          final warmUpSets = e.sets.where((s) => s.isWarmUp).length;
          final workingSets = totalSets - warmUpSets;

          return Exercise(
            id: const Uuid().v4(),
            name: e.name,
            sets: totalSets,
            workingSets: workingSets,
            warmUpSets: warmUpSets,
          );
        }).toList();

    // Use the original program ID from session
    final updatedProgram = WorkoutProgram(
      id: session.id, // Keep the same ID to overwrite
      title: session.programTitle, // Keep the same title
      exercises: exercises,
    );

    // Save will overwrite the existing program since we're using the same ID
    await dbService.saveWorkoutProgram(updatedProgram);
  }
}

// ====================================================================
// DEL 3: PROVIDERN
// Detta är den globala variabeln som låter vårt UI komma åt "hjärnan".
// ====================================================================

// Family provider - skapar en unik WorkoutStateNotifier för varje user ID
// Detta är NYCKELN till att hålla användares data separerade!
// När user ID ändras kommer Riverpod automatiskt att skapa en NY instans
final workoutProviderFamily = StateNotifierProvider.family<
  WorkoutStateNotifier,
  ActiveWorkoutState,
  String
>((ref, uid) {
  return WorkoutStateNotifier(DatabaseService(uid: uid));
});

// Huvudprovidern som delegerar till family provider baserat på inloggad användare
// OBS: Denna måste användas tillsammans med Consumer/ConsumerWidget för att fungera korrekt
final workoutProvider = StateNotifierProvider<
  WorkoutStateNotifier,
  ActiveWorkoutState
>((ref) {
  // Hämta nuvarande användare direkt från Firebase
  // Detta kommer att vara null första gången, men AuthGate garanterar att användaren är inloggad
  // när MainScreen visas
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    throw Exception("User not logged in, cannot create workout provider.");
  }

  // Skapa en NY WorkoutStateNotifier för denna användare
  // Observera: Riverpod kommer att cacha denna instans, vilket är problemet!
  return WorkoutStateNotifier(DatabaseService(uid: uid));
});

// GLÖM INTE: Lägg till denna copyWith-metod i din `WorkoutSession`-modellfil.
/*

*/
