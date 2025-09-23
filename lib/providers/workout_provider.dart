import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';
import '../models/workout_session_model.dart';
import '../services/database_service.dart';

// ====================================================================
// KLASS 1: STATE-OBJEKTET
// Detta är ett enkelt, "dumt" objekt som bara håller datan.
// Den är "immutable", vilket betyder att vi skapar en ny kopia varje
// gång något ändras, vilket är en bra praxis med Riverpod.
// ====================================================================
class ActiveWorkoutState {
  final WorkoutSession? session;
  final bool isRunning;
  final int elapsedSeconds;
  final WorkoutSession? staleSession; // För att hantera gamla, bortglömda pass

  ActiveWorkoutState({
    this.session,
    this.isRunning = false,
    this.elapsedSeconds = 0,
    this.staleSession,
  });

  // En hjälpmetod för att enkelt skapa en ny, uppdaterad kopia av statet.
  ActiveWorkoutState copyWith({
    WorkoutSession? session,
    bool? isRunning,
    int? elapsedSeconds,
    WorkoutSession? staleSession,
    bool clearStaleSession = false, // Specialflagga för att kunna nollställa
  }) {
    return ActiveWorkoutState(
      session: session ?? this.session,
      isRunning: isRunning ?? this.isRunning,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      staleSession: clearStaleSession ? null : staleSession ?? this.staleSession,
    );
  }
}

// ====================================================================
// KLASS 2: STATE NOTIFIER ("HJÄRNAN")
// Detta är den aktiva klassen som innehåller all logik för att
// starta, pausa, uppdatera och avsluta ett träningspass.
// ====================================================================
class WorkoutStateNotifier extends StateNotifier<ActiveWorkoutState> {
  final DatabaseService dbService;
  Timer? _timer;

  WorkoutStateNotifier(this.dbService) : super(ActiveWorkoutState());

  // ----- PUBLIKA METODER (anropas från UI) -----

Future<void> startWorkout(WorkoutProgram program) async {
  if (state.isRunning) return;

  // STEG 1: Hitta det senaste passet av denna typ
  final lastSession = await dbService.findLastSessionOfProgram(program.title);
  
  // STEG 2: Skapa det nya passet och fyll i gammal data där det är möjligt
  final initialExercises = program.exercises.map((currentExercise) {
    
    // Försök hitta en matchande övning i det gamla passet
    final lastExerciseData = lastSession?.completedExercises.firstWhere(
      (completedEx) => completedEx.name == currentExercise.name,
      orElse: () => CompletedExercise(name: "", sets: []), // Returnera en tom om ingen match hittas
    );

    // Skapa de nya seten
    return CompletedExercise(
      name: currentExercise.name,
      sets: List.generate(currentExercise.sets, (setIndex) {
        // Om det finns gammal data för detta set, använd den. Annars, skapa ett tomt set.
        if (lastExerciseData != null && setIndex < lastExerciseData.sets.length) {
          final lastSet = lastExerciseData.sets[setIndex];
          return CompletedSet(weight: lastSet.weight, reps: lastSet.reps, notes: lastSet.notes);
        } else {
          return CompletedSet(weight: 0, reps: 0, notes: null);
        }
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

  // STEG 3: Uppdatera statet och starta timern (som förut)
  state = ActiveWorkoutState(session: newSession, isRunning: true, elapsedSeconds: 0);
  _startTimer();
}

  void updateSetData(int exerciseIndex, int setIndex, {double? weight, int? reps, String? notes}) {
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
  );
  
  updatedExercises[exerciseIndex] = exerciseToUpdate.copyWith(sets: updatedSets);
  
  state = state.copyWith(session: state.session!.copyWith(completedExercises: updatedExercises));
  _saveStateToFirestore();
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
    if (session != null) {
      final now = DateTime.now();
      final timeSinceLastUpdate = now.difference(session.date);
      
      if (timeSinceLastUpdate.inHours >= 8) {
        state = state.copyWith(staleSession: session);
      } else {
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

  void _resumeWorkout(WorkoutSession session, int secondsToAdd) {
      final savedDurationInSeconds = session.durationInMinutes * 60;
      state = ActiveWorkoutState(
        session: session,
        isRunning: true,
        elapsedSeconds: savedDurationInSeconds + secondsToAdd,
        staleSession: null,
      );
      _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(mounted){
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
        if (state.elapsedSeconds % 15 == 0) {
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
  }
}

// ====================================================================
// DEL 3: PROVIDERN
// Detta är den globala variabeln som låter vårt UI komma åt "hjärnan".
// ====================================================================
final workoutProvider = StateNotifierProvider<WorkoutStateNotifier, ActiveWorkoutState>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw Exception("User not logged in, cannot create workout provider.");
  }
  return WorkoutStateNotifier(DatabaseService(uid: uid));
});

// GLÖM INTE: Lägg till denna copyWith-metod i din `WorkoutSession`-modellfil.
/*

*/