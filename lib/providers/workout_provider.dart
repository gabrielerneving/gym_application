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

  void startWorkout(WorkoutProgram program) {
    if (state.isRunning) return;

    final initialExercises = program.exercises.map((exercise) {
      return CompletedExercise(
        name: exercise.name,
        sets: List.generate(exercise.sets, (_) => CompletedSet(weight: 0, reps: 0)),
      );
    }).toList();

    final newSession = WorkoutSession(
      id: program.id, // Återanvänd program-id för enkelhetens skull
      programTitle: program.title,
      date: DateTime.now(),
      durationInMinutes: 0,
      completedExercises: initialExercises,
    );

    state = ActiveWorkoutState(session: newSession, isRunning: true, elapsedSeconds: 0);
    _startTimer();
  }

  void updateSetData(int exerciseIndex, int setIndex, double weight, int reps) {
    if (!state.isRunning || state.session == null) return;
    
    final updatedExercises = List<CompletedExercise>.from(state.session!.completedExercises);
    final exerciseToUpdate = updatedExercises[exerciseIndex];
    final updatedSets = List<CompletedSet>.from(exerciseToUpdate.sets);
    
    updatedSets[setIndex] = CompletedSet(weight: weight, reps: reps);
    updatedExercises[exerciseIndex] = CompletedExercise(name: exerciseToUpdate.name, sets: updatedSets);
    
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