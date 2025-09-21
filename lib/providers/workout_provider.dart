import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_session_model.dart';
import '../models/workout_model.dart';
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ----- STATE OBJECT -----
// Ett oföränderligt (immutable) objekt som representerar det aktuella tillståndet.
class ActiveWorkoutState {
  final WorkoutSession? session;
  final bool isRunning;
  final int elapsedSeconds;

  ActiveWorkoutState({
    this.session,
    this.isRunning = false,
    this.elapsedSeconds = 0,
  });

  // En hjälpmetod för att enkelt skapa en ny version av statet
  ActiveWorkoutState copyWith({
    WorkoutSession? session,
    bool? isRunning,
    int? elapsedSeconds,
  }) {
    return ActiveWorkoutState(
      session: session ?? this.session,
      isRunning: isRunning ?? this.isRunning,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}


// ----- STATE NOTIFIER (HJÄRNAN) -----
class WorkoutStateNotifier extends StateNotifier<ActiveWorkoutState> {
  final DatabaseService dbService;
  Timer? _timer;

  WorkoutStateNotifier(this.dbService) : super(ActiveWorkoutState());

  // Metod för att starta ett helt nytt pass
  void startWorkout(WorkoutProgram program) {
    if (state.isRunning) return; // Starta inte om ett pass redan är igång

    // Skapa en tom session baserad på programmet
    final initialExercises = program.exercises.map((exercise) {
      return CompletedExercise(
        name: exercise.name,
        sets: List.generate(exercise.sets, (_) => CompletedSet(weight: 0, reps: 0)),
      );
    }).toList();

    final newSession = WorkoutSession(
      id: const Uuid().v4(),
      programTitle: program.title,
      date: DateTime.now(),
      durationInMinutes: 0,
      completedExercises: initialExercises,
    );
    
    // Uppdatera statet och starta timern
    state = ActiveWorkoutState(session: newSession, isRunning: true, elapsedSeconds: 0);
    _startTimer();
  }

  // Metod för att uppdatera data för ett set
  void updateSetData(int exerciseIndex, int setIndex, double weight, int reps) {
    if (!state.isRunning) return;

    // Skapa en kopia av den nuvarande sessionen för att inte mutera state direkt
    final updatedExercises = List<CompletedExercise>.from(state.session!.completedExercises);
    final exerciseToUpdate = updatedExercises[exerciseIndex];
    final updatedSets = List<CompletedSet>.from(exerciseToUpdate.sets);
    
    updatedSets[setIndex] = CompletedSet(weight: weight, reps: reps);
    updatedExercises[exerciseIndex] = CompletedExercise(name: exerciseToUpdate.name, sets: updatedSets);

    // Uppdatera statet med den nya datan
    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
    );
    _saveStateToFirestore(); // Spara ändringen
  }

  // Metod för att avsluta och spara passet permanent
  Future<void> finishWorkout() async {
    if (!state.isRunning) return;
    _timer?.cancel();
    
    final finalSession = state.session!.copyWith(
      durationInMinutes: (state.elapsedSeconds / 60).ceil()
    );

    // Spara till den permanenta historiken
    await dbService.saveWorkoutSession(finalSession);
    // Ta bort den temporära filen
    await dbService.deleteActiveWorkoutState();

    // Återställ statet till tomt
    state = ActiveWorkoutState();
  }
  
  // Metod för att pausa (anropas när man lämnar skärmen)
  void pauseWorkout() {
    _timer?.cancel();
    if(state.isRunning){
       _saveStateToFirestore();
    }
  }

  // Metod som laddar ett sparat pass när appen startar
  Future<void> loadInitialState() async {
    final session = await dbService.loadActiveWorkoutState();
    if (session != null) {
      final secondsSinceSave = DateTime.now().difference(session.date).inSeconds;
      final savedDuration = session.durationInMinutes * 60;

      state = ActiveWorkoutState(
        session: session, 
        isRunning: true, 
        elapsedSeconds: savedDuration + secondsSinceSave
      );
      _startTimer();
    }
  }

  // ----- PRIVATA HJÄLPMETODER -----
  void _startTimer() {
    _timer?.cancel(); // Se till att en gammal timer inte körs
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      // Spara state var 15:e sekund för att inte spamma databasen
      if (state.elapsedSeconds % 15 == 0) {
        _saveStateToFirestore();
      }
    });
  }

  // Spara det nuvarande statet till den temporära filen i Firestore
  void _saveStateToFirestore() {
    if (!state.isRunning) return;
    final sessionToSave = state.session!.copyWith(
      // Vi "missbrukar" duration-fältet för att spara sekunder temporärt
      durationInMinutes: (state.elapsedSeconds / 60).round(),
      date: DateTime.now() // Uppdatera datumet för att kunna återuppta korrekt
    );
    dbService.saveActiveWorkoutState(sessionToSave);
  }
}

// ----- PROVIDERN -----
// Skapar och tillhandahåller vår WorkoutStateNotifier till resten av appen.
final workoutProvider = StateNotifierProvider<WorkoutStateNotifier, ActiveWorkoutState>((ref) {
  // Här skulle du i en större app hämta uid från en annan provider,
  // men detta fungerar utmärkt.
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    // Om ingen är inloggad, skapa en "dummy"-notifier som inte gör något.
    throw Exception("User not logged in, cannot create workout provider.");
  }
  return WorkoutStateNotifier(DatabaseService(uid: uid));
});

