import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';
import '../models/workout_session_model.dart';
import '../services/database_service.dart';

// State-objekt för aktivt träningspass (immutable)
class ActiveWorkoutState {
  final WorkoutSession? session;
  final bool isRunning;
  final int elapsedSeconds;
  final WorkoutSession? staleSession; // Gamla obesvarade pass
  final Set<String> editedFields; // Spårar redigerade fält
  final Map<String, dynamic> placeholders; // Basvärden från förra passet

  ActiveWorkoutState({
    this.session,
    this.isRunning = false,
    this.elapsedSeconds = 0,
    this.staleSession,
    Set<String>? editedFields,
    Map<String, dynamic>? placeholders,
  })  : editedFields = editedFields ?? <String>{},
        placeholders = placeholders ?? <String, dynamic>{};

  // Skapar ny kopia av state med uppdateringar
  ActiveWorkoutState copyWith({
    WorkoutSession? session,
    bool? isRunning,
    int? elapsedSeconds,
    WorkoutSession? staleSession,
    bool clearStaleSession = false, // Flagga för att nollställa staleSession
    Set<String>? editedFields,
    Map<String, dynamic>? placeholders,
  }) {
    return ActiveWorkoutState(
      session: session ?? this.session,
      isRunning: isRunning ?? this.isRunning,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      staleSession: clearStaleSession ? null : staleSession ?? this.staleSession,
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
    : super(ActiveWorkoutState(editedFields: <String>{}, placeholders: <String, dynamic>{}));

Future<void> startWorkout(WorkoutProgram program) async {
  if (state.isRunning) return;

  // STEG 1: Hitta senaste passet av denna typ
  final lastSession = await dbService.findLastSessionOfProgram(program.title);
  
  // STEG 2: Skapa nytt pass med tomma värden
  final initialExercises = program.exercises.map((currentExercise) {
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
  final Map<String, dynamic> placeholders = <String, dynamic>{};
  if (lastSession != null) {
    for (int exIndex = 0; exIndex < program.exercises.length; exIndex++) {
      final currentExercise = program.exercises[exIndex];
      
      // Försök hitta en matchande övning i det gamla passet
      final lastExerciseData = lastSession.completedExercises.firstWhere(
        (completedEx) => completedEx.name == currentExercise.name,
        orElse: () => CompletedExercise(name: "", sets: []),
      );

      // Skapa placeholders från förra passets data
      for (int setIndex = 0; setIndex < currentExercise.sets; setIndex++) {
        if (lastExerciseData.sets.isNotEmpty && setIndex < lastExerciseData.sets.length) {
          final lastSet = lastExerciseData.sets[setIndex];
          if (lastSet.weight > 0) {
            placeholders['w_${exIndex}_$setIndex'] = lastSet.weight;
          }
          if (lastSet.reps > 0) {
            placeholders['r_${exIndex}_$setIndex'] = lastSet.reps;
          }
          if (lastSet.notes != null && lastSet.notes!.isNotEmpty) {
            placeholders['n_${exIndex}_$setIndex'] = lastSet.notes;
          }
          if (lastSet.rir != null && lastSet.rir! > 0) {
            placeholders['rir_${exIndex}_$setIndex'] = lastSet.rir;
          }
        }
      }
    }
  }

  state = ActiveWorkoutState(
    session: newSession,
    isRunning: true,
    elapsedSeconds: 0,
    editedFields: <String>{},
    placeholders: placeholders,
  );
  // Persistera även placeholders till Firestore så de överlever app-restart
  unawaited(dbService.saveActivePlaceholders(placeholders));
  _startTimer();
}

  void updateSetData(int exerciseIndex, int setIndex, {double? weight, int? reps, String? notes, int? rir}) {
  if (!state.isRunning || state.session == null) return;
  
  // Använd copyWith för en mycket renare och säkrare uppdatering
  final updatedExercises = List<CompletedExercise>.from(state.session!.completedExercises);
  final exerciseToUpdate = updatedExercises[exerciseIndex];
  final updatedSets = List<CompletedSet>.from(exerciseToUpdate.sets);
  
  // Hämta det nuvarande setet och skapa en uppdaterad version
  final currentSet = updatedSets[setIndex];
  updatedSets[setIndex] = currentSet.copyWith(
    weight: weight,
    reps: reps,
    notes: notes,
    rir: rir,
  );
  
  updatedExercises[exerciseIndex] = exerciseToUpdate.copyWith(sets: updatedSets);
  
  state = state.copyWith(session: state.session!.copyWith(completedExercises: updatedExercises));
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
    
    final finalSession = state.session!.copyWith(
      id: const Uuid().v4(), // Ge den ett nytt, unikt ID för historiken
      durationInMinutes: (state.elapsedSeconds / 60).ceil(),
      date: DateTime.now()
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

  Future<void> loadInitialState() async {
    final session = await dbService.loadActiveWorkoutState();
    final edited = await dbService.loadActiveEditedKeys();
    var placeholders = await dbService.loadActivePlaceholders();
    
    if (session != null) {
      // Om placeholders är tomma (kan hända vid app-restart), 
      // hämta placeholders från föregående AVSLUTADE pass av samma typ
      if (placeholders.isEmpty) {
        final lastFinishedSession = await dbService.findLastSessionOfProgram(session.programTitle);
        if (lastFinishedSession != null) {
          placeholders = _buildPlaceholdersFromSession(lastFinishedSession);
          // Spara dem för framtida användning
          unawaited(dbService.saveActivePlaceholders(placeholders));
        }
      }
      
      final now = DateTime.now();
      final timeSinceLastUpdate = now.difference(session.date);
      
      if (timeSinceLastUpdate.inHours >= 8) {
        state = state.copyWith(staleSession: session, editedFields: edited, placeholders: placeholders);
      } else {
        state = state.copyWith(editedFields: edited, placeholders: placeholders);
        _resumeWorkout(session, timeSinceLastUpdate.inSeconds);
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
    for (int exIndex = 0; exIndex < session.completedExercises.length; exIndex++) {
      final ex = session.completedExercises[exIndex];
      for (int setIndex = 0; setIndex < ex.sets.length; setIndex++) {
        final set = ex.sets[setIndex];
        if (set.weight > 0) placeholders['w_${exIndex}_$setIndex'] = set.weight;
        if (set.reps > 0) placeholders['r_${exIndex}_$setIndex'] = set.reps;
        if (set.notes != null && set.notes!.isNotEmpty) {
          placeholders['n_${exIndex}_$setIndex'] = set.notes;
        }
      }
    }
    return placeholders;
  }

  void _resumeWorkout(WorkoutSession session, int secondsToAdd) {
      final savedDurationInSeconds = session.durationInMinutes * 60;
      final totalElapsedSeconds = savedDurationInSeconds + secondsToAdd;
      
      // Kontrollera om träningspasset har pågått för länge redan när vi återupptar (8 timmar = 28800 sekunder)
      if (totalElapsedSeconds >= 28800) {
        print('Workout exceeded 8 hours, auto-finishing on resume...');
        // Avsluta workoutet automatiskt istället för att återuppta
        dbService.deleteActiveWorkoutState();
        state = state.copyWith(clearStaleSession: true);
        return;
      }
      
      state = ActiveWorkoutState(
        session: session,
        isRunning: true,
        elapsedSeconds: totalElapsedSeconds,
        staleSession: null,
        editedFields: state.editedFields.isNotEmpty ? state.editedFields : <String>{},
      );
      _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(mounted){
        final newElapsedSeconds = state.elapsedSeconds + 1;
        state = state.copyWith(elapsedSeconds: newElapsedSeconds);
        
        // Kontrollera om träningspasset har pågått för länge (8 timmar = 28800 sekunder)
        if (newElapsedSeconds >= 28800) {
          print('Workout has been running for 8 hours, auto-finishing...');
          finishWorkout();
          return;
        }
        
        if (newElapsedSeconds % 15 == 0) {
          _saveStateToFirestore();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _saveStateToFirestore() {
    if (!state.isRunning || state.session == null) return;
    final sessionToSave = state.session!.copyWith(
      durationInMinutes: (state.elapsedSeconds / 60).round(),
      date: DateTime.now(),
    );
    dbService.saveActiveWorkoutState(sessionToSave);
    // Persist edited fields as well
    dbService.saveActiveEditedKeys(state.editedFields);
  }
}

// ====================================================================
// DEL 3: PROVIDERN
// Detta är den globala variabeln som låter vårt UI komma åt "hjärnan".
// ====================================================================

// Family provider - skapar en unik WorkoutStateNotifier för varje user ID
// Detta är NYCKELN till att hålla användares data separerade!
// När user ID ändras kommer Riverpod automatiskt att skapa en NY instans
final workoutProviderFamily = StateNotifierProvider.family<WorkoutStateNotifier, ActiveWorkoutState, String>((ref, uid) {
  return WorkoutStateNotifier(DatabaseService(uid: uid));
});

// Huvudprovidern som delegerar till family provider baserat på inloggad användare
// OBS: Denna måste användas tillsammans med Consumer/ConsumerWidget för att fungera korrekt
final workoutProvider = StateNotifierProvider<WorkoutStateNotifier, ActiveWorkoutState>((ref) {
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