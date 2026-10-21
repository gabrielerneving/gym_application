import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_model.dart';
import '../models/workout_session_model.dart';
import '../models/exercise_model.dart';
import '../services/database_service.dart';
import '../utils/placeholder_history.dart';

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

  /// Tidigare pass som placeholders byggs från. Laddas en gång per pass och
  /// återanvänds när övningar eller set läggs till under passet.
  List<WorkoutSession>? _history;

  static const List<String> _keyPrefixes = ['w_', 'r_', 'n_', 'rir_'];

  /// Osparade ändringar i set-data eller redigerade fält. Sparas av timern
  /// (högst en gång per sekund) i stället för vid varje tangenttryck.
  bool _dirty = false;

  /// Minuten som senast sparades — längden sparas en gång per minut.
  int _lastSavedMinute = -1;

  /// Sparar direkt när appen lämnar förgrunden, så att debouncingen aldrig
  /// tappar det senaste setet om appen dödas i bakgrunden.
  late final AppLifecycleListener _lifecycle;

  WorkoutStateNotifier(this.dbService)
    : super(
        ActiveWorkoutState(
          editedFields: <String>{},
          placeholders: <String, dynamic>{},
        ),
      ) {
    _lifecycle = AppLifecycleListener(
      onStateChange: (lifecycleState) {
        if (lifecycleState != AppLifecycleState.resumed && _dirty) {
          _saveStateToFirestore();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Startar ett nytt pass. Returnerar false om inget startades — ett pass
  /// pågår redan, eller ett avbrutet/oavslutat pass återställdes nyss och får
  /// inte skrivas över.
  Future<bool> startWorkout(WorkoutProgram program) async {
    // Vänta in återställningen av ett pass som appen dödades mitt i. Annars
    // skriver ett snabbt tryck på Start över det sparade passet.
    try {
      await loadInitialState();
    } catch (e) {
      debugPrint('Could not restore the active workout: $e');
    }
    if (state.isRunning || state.staleSession != null) return false;

    // STEG 1: Skapa nytt pass med tomma värden — de första seten är warm-up
    final initialExercises =
        program.exercises.map((currentExercise) {
          return CompletedExercise(
            name: currentExercise.name,
            sets: List.generate(currentExercise.sets, (setIndex) {
              return CompletedSet(
                weight: 0,
                reps: 0,
                notes: null,
                isWarmUp: setIndex < currentExercise.warmUpSets,
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

    final startTime = DateTime.now();

    // STEG 2: Starta direkt — skärmen ska inte vänta på historiken.
    // Placeholders fylls i så fort tidigare pass har hämtats.
    _history = null;
    state = ActiveWorkoutState(
      session: newSession,
      isRunning: true,
      elapsedSeconds: 0,
      startTime: startTime,
      editedFields: <String>{},
      placeholders: <String, dynamic>{},
    );
    unawaited(dbService.saveActiveStartTime(startTime));
    _saveStateToFirestore();
    _startTimer();

    // STEG 3: Placeholders från tidigare pass — hämtas i bakgrunden så att
    // skärmen kan öppnas direkt.
    unawaited(_loadPlaceholders(startTime, program.title));
    return true;
  }

  /// Varje set letar bakåt i historiken tills det hittar ett loggat värde, så
  /// en överhoppad övning blir inte tom nästa gång.
  Future<void> _loadPlaceholders(DateTime startTime, String programTitle) async {
    final history = await _ensureHistory(programTitle);
    if (!_isSameRun(startTime)) return;
    final placeholders = buildPlaceholders(
      exercises: state.session!.completedExercises,
      history: history,
      programTitle: programTitle,
    );
    _applyPlaceholders(placeholders);
  }

  /// Byter placeholders och räknar om alla lånade värden mot dem — ett set där
  /// bara reps skrevs in innan ledtrådarna kom (eller innan ett set ovanför
  /// togs bort) ska spara vikten som faktiskt visas i fältet.
  void _applyPlaceholders(Map<String, dynamic> placeholders) {
    state = state.copyWith(placeholders: placeholders);
    final session = state.session;
    if (session != null) {
      var changed = false;
      final exercises = [
        for (final exercise in session.completedExercises)
          exercise.copyWith(
            sets: [
              for (var i = 0; i < exercise.sets.length; i++)
                () {
                  final resolved =
                      _resolveSet(exercise.sets[i], '${exercise.name}_$i');
                  if (!identical(resolved, exercise.sets[i])) changed = true;
                  return resolved;
                }(),
            ],
          ),
      ];
      if (changed) {
        state = state.copyWith(
          session: session.copyWith(completedExercises: exercises),
        );
        _dirty = true;
      }
    }
    unawaited(dbService.saveActivePlaceholders(placeholders));
  }

  /// Fyller ett set:s tomma vikt med förra gångens värde enligt regeln i
  /// [updateSetData], och räknar om progressionen. Returnerar samma objekt om
  /// inget ändrades.
  CompletedSet _resolveSet(CompletedSet set, String keyBase) {
    final weightEdited = state.editedFields.contains('w_$keyBase');
    final repsEdited = state.editedFields.contains('r_$keyBase');
    final hintWeight = state.placeholders['w_$keyBase'];

    var weight = set.weight;
    var reps = set.reps;
    if (!weightEdited) {
      weight = repsEdited && reps > 0 && hintWeight is num
          ? hintWeight.toDouble()
          : 0;
    }
    if (!repsEdited) reps = 0;

    final ({int? reps, double? weight}) progression = set.isWarmUp
        ? (reps: null, weight: null)
        : _progressionAgainstPlaceholders(keyBase, weight, reps);

    if (weight == set.weight &&
        reps == set.reps &&
        progression.reps == set.progression &&
        progression.weight == set.weightProgression) {
      return set;
    }
    return set.copyWith(
      weight: weight,
      reps: reps,
      progression: progression.reps,
      weightProgression: progression.weight,
    );
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
    final keyBase = '${exerciseToUpdate.name}_$setIndex';

    // Ett tomt viktfält som visar förra passets värde betyder "samma vikt som
    // sist" så fort reps skrivs in. Reps lånas aldrig: det är reps som säger
    // att setet är gjort, och vikten skrivs ofta in innan man lyfter. Fält som
    // inte redigerats är alltid antingen lånade eller tomma — se _resolveSet.
    updatedSets[setIndex] = _resolveSet(
      currentSet.copyWith(
        weight: weight,
        reps: reps,
        notes: notes,
        rir: rir,
      ),
      keyBase,
    );

    updatedExercises[exerciseIndex] = exerciseToUpdate.copyWith(
      sets: updatedSets,
    );

    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
    );
    _dirty = true;
  }

  // Markera ett fält som redigerat (anropas från UI när användaren skriver eller swipar)
  void markFieldEdited(String key) {
    final updated = Set<String>.from(state.editedFields)..add(key);
    state = state.copyWith(editedFields: updated);
    _dirty = true;
  }

  void markFieldsEdited(Iterable<String> keys) {
    final updated = Set<String>.from(state.editedFields)..addAll(keys);
    state = state.copyWith(editedFields: updated);
    _dirty = true;
  }

  void unmarkFieldEdited(String key) {
    if (!state.editedFields.contains(key)) return;
    final updated = Set<String>.from(state.editedFields)..remove(key);
    state = state.copyWith(editedFields: updated);
    _dirty = true;
  }

  void clearEditedFields() {
    if (state.editedFields.isEmpty) return;
    state = state.copyWith(editedFields: <String>{});
    _dirty = true;
  }

  Future<void> finishWorkout() async {
    if (!state.isRunning || state.session == null) return;
    _timer?.cancel();

    // Beräkna progression för varje set genom att jämföra med placeholders.
    // Görs innan tomma set rensas bort — nycklarna bygger på set-index.
    final updatedExercises = <CompletedExercise>[];
    for (final exercise in state.session!.completedExercises) {
      final updatedSets = <CompletedSet>[];

      for (int setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
        final set = exercise.sets[setIndex];
        final ({int? reps, double? weight}) progression = set.isWarmUp
            ? (reps: null, weight: null)
            : _progressionAgainstPlaceholders(
                '${exercise.name}_$setIndex',
                set.weight,
                set.reps,
              );

        updatedSets.add(
          set.copyWith(
            progression: progression.reps,
            weightProgression: progression.weight,
          ),
        );
      }

      // Bara set med reps sparas i historiken; en överhoppad övning försvinner
      // helt i stället för att ligga kvar som en rad nollor.
      final loggedSets = updatedSets.where(isSetLogged).toList();
      if (loggedSets.isNotEmpty) {
        updatedExercises.add(exercise.copyWith(sets: loggedSets));
      }
    }

    // Inget loggat alls — spara inte ett tomt pass i historiken.
    if (updatedExercises.isEmpty) {
      await discardWorkout();
      return;
    }

    final finalSession = state.session!.copyWith(
      // Samma id varje gång samma pass sparas: om appen dödas innan det
      // aktiva passet hunnit raderas och passet avslutas igen, skrivs samma
      // dokument över i stället för att historiken får en dubblett.
      id: '${state.session!.id}_${state.session!.date.millisecondsSinceEpoch}',
      durationInMinutes: (state.elapsedSeconds / 60).ceil(),
      // session.date är när passet startade — det är det datum passet hör till,
      // även om det avslutas efter midnatt eller återupptas dagen efter.
      completedExercises: updatedExercises,
    );

    try {
      await dbService.saveWorkoutSession(finalSession);
    } catch (_) {
      // Passet pågår fortfarande — utan detta stod timern still efter ett
      // misslyckat sparförsök.
      _startTimer();
      rethrow;
    }
    _timer?.cancel();
    _history = null;
    state = ActiveWorkoutState();
    // Väntar inte: utan täckning tar raderingen upp till en timeout, och
    // passet är redan sparat. Firestore kör den när nätet kommer tillbaka.
    unawaited(dbService.deleteActiveWorkoutState());
  }

  /// Historiken som passet jämförs mot i sammanfattningen — samma som
  /// placeholders byggdes från, så siffrorna stämmer med de grå ledtrådarna.
  /// Läs den innan [finishWorkout], som släpper den.
  Future<List<WorkoutSession>> comparisonHistory() => _ensureHistory();

  /// Avbryter passet utan att spara något i historiken.
  Future<void> discardWorkout() async {
    if (state.session == null) return;
    _timer?.cancel();
    _history = null;
    // State nollställs först så att inga fler sparningar hinner skriva tillbaka
    // dokumentet efter att det raderats.
    state = ActiveWorkoutState();
    unawaited(dbService.deleteActiveWorkoutState());
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

  /// Återställer ett pass som appen stängdes (eller dödades) mitt i. Körs en
  /// gång per användare; senare anrop väntar bara in samma laddning, så
  /// [startWorkout] kan vänta på den utan att läsa dokumentet igen.
  Future<void> loadInitialState() {
    return _initialLoad ??= _restoreActiveWorkout().catchError((Object e) {
      debugPrint('Error restoring active workout: $e');
      _initialLoad = null; // Försök igen nästa gång
    });
  }

  Future<void>? _initialLoad;

  Future<void> _restoreActiveWorkout() async {
    if (state.isRunning) return;

    final saved = await dbService.loadActiveSession();
    if (saved == null) return;
    final session = saved.session;
    var placeholders = saved.placeholders;

    // Om placeholders saknas (t.ex. om appen dog innan de hann sparas),
    // bygg dem på nytt från historiken.
    final rebuiltPlaceholders = placeholders.isEmpty;
    if (rebuiltPlaceholders) {
      final history = await _ensureHistory(session.programTitle);
      placeholders = buildPlaceholders(
        exercises: session.completedExercises,
        history: history,
        programTitle: session.programTitle,
      );
    }
    if (state.isRunning) return;

    // Använd sparad startTime om den finns, annars fallback till session.date
    final actualStartTime = saved.startTime ?? session.date;
    final actualElapsedTime = DateTime.now().difference(actualStartTime);

    state = state.copyWith(
      staleSession: actualElapsedTime.inHours >= 8 ? session : null,
      editedFields: saved.editedKeys,
      placeholders: placeholders,
    );
    if (actualElapsedTime.inHours < 8) {
      _resumeWorkout(session, startTime: actualStartTime);
    }
    // Sparas först nu: skrevs de innan kontrollen ovan kunde de återskapa ett
    // dokument som hunnit raderas.
    if (rebuiltPlaceholders) {
      unawaited(dbService.saveActivePlaceholders(placeholders));
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
    // Fortsätt från den tid som hann sparas. Räknat från starttiden (minst
    // 8 timmar bak) skulle passet avslutas i samma sekund som det återupptas.
    final startTime = DateTime.now().subtract(
      Duration(minutes: session.durationInMinutes),
    );
    _resumeWorkout(session, startTime: startTime);
    unawaited(dbService.saveActiveStartTime(startTime));
  }

  // ----- PRIVATA HJÄLPMETODER -----

  /// Sant om passet som startades vid [startTime] fortfarande pågår — skyddar
  /// asynkrona uppdateringar från att skriva in i ett pass som hunnit avslutas.
  bool _isSameRun(DateTime? startTime) =>
      startTime != null && state.isRunning && state.startTime == startTime;

  Future<List<WorkoutSession>> _ensureHistory([String? programTitle]) async {
    final cached = _history;
    if (cached != null) return cached;

    final title = programTitle ?? state.session?.programTitle ?? '';
    final results = await Future.wait([
      dbService.getRecentWorkoutSessions(),
      dbService.findLastSessionOfProgram(title),
    ]);
    final recent = results[0] as List<WorkoutSession>;
    final lastOfProgram = results[1] as WorkoutSession?;

    // Senaste passet av samma program kan ligga längre bak än de senaste
    // passen totalt — ta med det så att programmets egen historik finns.
    final history = [
      ...recent,
      if (lastOfProgram != null &&
          recent.every((s) => s.id != lastOfProgram.id))
        lastOfProgram,
    ];
    _history = history;
    return history;
  }

  /// Bygger om en övnings placeholders efter att dess set ändrats, så att ett
  /// tillagt set eller en tillagd övning också får förra gångens värden.
  Future<void> _refreshExercisePlaceholders(String exerciseName) async {
    final startTime = state.startTime;
    final history = await _ensureHistory();
    if (!_isSameRun(startTime)) return;

    final session = state.session!;
    final updated = Map<String, dynamic>.from(state.placeholders)
      ..removeWhere((key, _) => _parseKey(key, exerciseName) != null);
    for (final exercise in session.completedExercises) {
      if (exercise.name != exerciseName) continue;
      updated.addAll(
        buildExercisePlaceholders(
          exercise: exercise,
          history: history,
          programTitle: session.programTitle,
        ),
      );
    }

    _applyPlaceholders(updated);
  }

  /// Delar upp en nyckel som `w_Bench Press_2` i prefix och set-index, eller
  /// null om nyckeln inte hör till [exerciseName]. Kräver att resten efter
  /// namnet är ett heltal, så "Bench Press" krockar inte med "Bench Press
  /// Close Grip".
  ({String prefix, int index})? _parseKey(String key, String exerciseName) {
    for (final prefix in _keyPrefixes) {
      final head = '$prefix${exerciseName}_';
      if (!key.startsWith(head)) continue;
      final index = int.tryParse(key.substring(head.length));
      if (index != null) return (prefix: prefix, index: index);
    }
    return null;
  }

  ({int? reps, double? weight}) _progressionAgainstPlaceholders(
    String keyBase,
    double weight,
    int reps,
  ) {
    final previousReps = state.placeholders['r_$keyBase'];
    if (previousReps is! num) return (reps: null, weight: null);
    // Reps utan vikt-placeholder betyder att förra setet var kroppsvikt.
    final hintWeight = state.placeholders['w_$keyBase'];
    final previousWeight = hintWeight is num ? hintWeight.toDouble() : 0.0;

    int? repProgression;
    double? weightProgression;

    // Rep progression räknas bara när vikten är densamma (även 0 = kroppsvikt)
    if (weight == previousWeight && reps > 0) {
      final difference = reps - previousReps.toInt();
      if (difference != 0) repProgression = difference;
    }

    // Vikt progression räknas alltid när vikten ändras, oavsett reps
    if (weight > 0) {
      final difference = weight - previousWeight;
      if (difference != 0) weightProgression = difference;
    }

    return (reps: repProgression, weight: weightProgression);
  }

  void _resumeWorkout(WorkoutSession session, {required DateTime startTime}) {
    // VIKTIGT: Behåll placeholders och editedFields från nuvarande state
    state = ActiveWorkoutState(
      session: session,
      isRunning: true,
      elapsedSeconds: DateTime.now().difference(startTime).inSeconds,
      startTime: startTime,
      staleSession: null,
      editedFields: state.editedFields,
      placeholders: state.placeholders,
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
            timer.cancel();
            unawaited(finishWorkout().catchError((Object e) {
              debugPrint('Auto-finish failed: $e');
            }));
            return;
          }

          // Spara ändringar inom en sekund, och längden en gång per minut —
          // inte två fulla dokument var 5:e sekund oavsett om något ändrats.
          if (_dirty || actualElapsedSeconds ~/ 60 != _lastSavedMinute) {
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
    _dirty = false;
    _lastSavedMinute = state.elapsedSeconds ~/ 60;
    // OBS: Överskriver INTE session.date här — startTime sparas separat.
    // Om vi sätter date: DateTime.now() vid varje save, och startTime saknas vid resume,
    // blir elapsed-tid felberäknad.
    final sessionToSave = state.session!.copyWith(
      durationInMinutes: (state.elapsedSeconds / 60).round(),
    );
    // Ett dokument, en skrivning: passet och redigerade fält tillsammans
    unawaited(dbService.saveActiveWorkout(sessionToSave, state.editedFields));
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
    unawaited(_refreshExercisePlaceholders(exercise.name));
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

    // Seten efter det borttagna flyttar upp ett steg. Flytta deras
    // redigerat-markeringar med, annars visas inskrivna värden som tomma fält.
    final newEditedFields = <String>{};
    for (final key in state.editedFields) {
      final parsed = _parseKey(key, exercise.name);
      if (parsed == null || parsed.index < setIndex) {
        newEditedFields.add(key);
      } else if (parsed.index > setIndex) {
        newEditedFields.add('${parsed.prefix}${exercise.name}_${parsed.index - 1}');
      }
    }

    // Placeholders byggs om från historiken nedan; tills dess tas de bort för
    // de set som bytt plats så att ingen rad visar fel värde.
    final newPlaceholders = Map<String, dynamic>.from(state.placeholders)
      ..removeWhere((key, _) {
        final parsed = _parseKey(key, exercise.name);
        return parsed != null && parsed.index >= setIndex;
      });

    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
      placeholders: newPlaceholders,
      editedFields: newEditedFields,
    );
    _saveStateToFirestore();
    unawaited(_refreshExercisePlaceholders(exercise.name));
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
    unawaited(_refreshExercisePlaceholders(exerciseName));
  }

  void removeExercise(int exerciseIndex) {
    if (!state.isRunning || state.session == null) return;

    final exerciseToRemove = state.session!.completedExercises[exerciseIndex];
    final updatedExercises = List<CompletedExercise>.from(
      state.session!.completedExercises,
    )..removeAt(exerciseIndex);

    // Ta bort alla placeholders och edited fields för den borttagna övningen.
    // _parseKey kräver exakt namn + set-index, så "Bench Press" rör inte
    // "Bench Press Close Grip".
    final exerciseName = exerciseToRemove.name;
    final newPlaceholders = Map<String, dynamic>.from(state.placeholders)
      ..removeWhere((key, _) => _parseKey(key, exerciseName) != null);
    final newEditedFields = Set<String>.from(state.editedFields)
      ..removeWhere((key) => _parseKey(key, exerciseName) != null);

    state = state.copyWith(
      session: state.session!.copyWith(completedExercises: updatedExercises),
      placeholders: newPlaceholders,
      editedFields: newEditedFields,
    );
    _saveStateToFirestore();
    // Samma övning kan finnas kvar en gång till i passet — bygg om dess
    // placeholders i stället för att bara spara borttagningen.
    unawaited(_refreshExercisePlaceholders(exerciseName));
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

/// Sant när det finns ett pågående eller oavslutat pass — då flyter passets
/// pill ovanför nav-baren och snackbars måste lägga sig ovanför den.
/// Läser aldrig [workoutProvider] utan inloggad användare (den kastar då).
final hasWorkoutAccessoryProvider = Provider.autoDispose<bool>((ref) {
  if (FirebaseAuth.instance.currentUser == null) return false;
  return ref.watch(
    workoutProvider.select((s) => s.isRunning || s.staleSession != null),
  );
});
