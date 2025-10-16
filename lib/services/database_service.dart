import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_model.dart';
import '../models/master_exercise_model.dart';
import '../models/exercise_model.dart';
import '../models/workout_session_model.dart';
import '../models/standard_workout_template.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Användarens unika ID
  final String uid;
  DatabaseService({required this.uid});

  // Sparar träningsprogram i Firebase
  Future<void> saveWorkoutProgram(WorkoutProgram program) async {
    try {
      // Firebase-struktur: users -> {userId} -> workout_programs -> {programId}
      
      // Referens till användarens träningsprogram
      final collectionRef = _db.collection('users').doc(uid).collection('workout_programs');

      await collectionRef.doc(program.id).set({
        'title': program.title,
        'id': program.id,
        // Konvertera övningar till Firestore-format
        'exercises': program.exercises.map((exercise) => {
          'id': exercise.id,
          'name': exercise.name,
          'sets': exercise.sets,
          'workingSets': exercise.workingSets,
          'warmUpSets': exercise.warmUpSets,
        }).toList(),
      });
    } catch (e) {
      print('Error saving workout program: $e');
      rethrow;
    }
  }

// Hämtar stream av träningsprogram (real-time updates)
Stream<List<WorkoutProgram>> getWorkoutPrograms() {
  final collectionRef = _db.collection('users').doc(uid).collection('workout_programs');

  return collectionRef.snapshots().map((snapshot) {
    return snapshot.docs.map((doc) {
      return WorkoutProgram.fromFirestore(doc.data());
    }).toList();
  });
}

// Metod för att spara en ny "master"-övning
Future<void> saveMasterExercise(MasterExercise exercise) async {
  final collectionRef = _db.collection('users').doc(uid).collection('master_exercises');
  await collectionRef.doc(exercise.id).set(exercise.toMap());
}

// Metod för att hämta en STREAM av "master"-övningar för en specifik kategori
Stream<List<MasterExercise>> getMasterExercisesByCategory(String category) {
  final collectionRef = _db.collection('users').doc(uid).collection('master_exercises');
  
  // Använd .where() för att filtrera resultatet
  return collectionRef.where('category', isEqualTo: category).snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => MasterExercise.fromFirestore(doc.data())).toList();
  });
}

Future<void> deleteWorkoutProgram(String programId) async {
  try {
    // Skapa en referens till det specifika dokumentet
    final docRef = _db.collection('users').doc(uid).collection('workout_programs').doc(programId);
    
    // Anropa .delete() för att ta bort det
    await docRef.delete();
  } catch (e) {
    print('Error deleting workout program: $e');
    // Kasta felet vidare om du vill hantera det i UI:t
    rethrow;
  }
}

// Metod för att uppdatera ett befintligt träningsprogram
Future<void> updateWorkoutProgram(WorkoutProgram program) async {
  try {
    // Skapa en referens till det specifika dokumentet
    final docRef = _db.collection('users').doc(uid).collection('workout_programs').doc(program.id);
    
    // Använd .update() för att ändra fälten i dokumentet.
    // Vi måste konvertera vårt program-objekt till en Map igen.
    await docRef.update({
      'title': program.title,
      'exercises': program.exercises.map((exercise) => {
        'id': exercise.id,
        'name': exercise.name,
        'sets': exercise.sets,
        'workingSets': exercise.workingSets,
        'warmUpSets': exercise.warmUpSets,
      }).toList(),
    });
  } catch (e) {
    print('Error updating workout program: $e');
    rethrow;
  }
}

// Metod för att spara en slutförd träningssession
Future<void> saveWorkoutSession(WorkoutSession session) async {
  try {
    // Skapa en referens till en ny collection för historik
    final collectionRef = _db.collection('users').doc(uid).collection('workout_sessions');
    
    // Spara sessionen med sitt unika ID
    await collectionRef.doc(session.id).set(session.toMap());
  } catch (e) {
    print('Error saving workout session: $e');
    rethrow;
  }
}

// Metod för att hämta en STREAM av slutförda träningssessioner
Stream<List<WorkoutSession>> getWorkoutSessions() {
  final collectionRef = _db.collection('users').doc(uid).collection('workout_sessions')
      .orderBy('date', descending: true); // Sortera så att den senaste kommer först

  return collectionRef.snapshots().map((snapshot) {
    return snapshot.docs.map((doc) {
      // Vi behöver en fromFirestore-metod i WorkoutSession-modellen
      return WorkoutSession.fromFirestore(doc.data());
    }).toList();
  });
}

// Spara det pågående passets state
Future<void> saveActiveWorkoutState(WorkoutSession session) async {
  final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
  // merge: true för att inte radera extra fält (t.ex. editedKeys)
  await docRef.set(session.toMap(), SetOptions(merge: true));
}

// Spara vilka fält som användaren redigerat under pågående pass
Future<void> saveActiveEditedKeys(Set<String> editedKeys) async {
  final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
  await docRef.set({'editedKeys': editedKeys.toList()}, SetOptions(merge: true));
}

// Läs det pågående passet (om det finns)
Future<WorkoutSession?> loadActiveWorkoutState() async {
  final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
  final snapshot = await docRef.get();
  if (snapshot.exists) {
    return WorkoutSession.fromFirestore(snapshot.data()!);
  }
  return null;
}

// Läs tillbaka editedKeys för det pågående passet
Future<Set<String>> loadActiveEditedKeys() async {
  final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
  final snapshot = await docRef.get();
  if (!snapshot.exists) return <String>{};
  final data = snapshot.data();
  if (data == null) return <String>{};
  final list = data['editedKeys'];
  if (list is List) {
    return Set<String>.from(list.map((e) => e.toString()));
  }
  return <String>{};
}

// Spara placeholders (förra passets värden) per fält
Future<void> saveActivePlaceholders(Map<String, dynamic> placeholders) async {
  final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
  await docRef.set({'placeholders': placeholders}, SetOptions(merge: true));
}

Future<Map<String, dynamic>> loadActivePlaceholders() async {
  final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
  final snapshot = await docRef.get();
  if (!snapshot.exists) return <String, dynamic>{};
  final data = snapshot.data();
  if (data == null) return <String, dynamic>{};
  final ph = data['placeholders'];
  if (ph is Map<String, dynamic>) return ph;
  if (ph is Map) return Map<String, dynamic>.from(ph);
  return <String, dynamic>{};
}

 // Metod för att ta bort det temporära "pågående pass"-dokumentet
  Future<void> deleteActiveWorkoutState() async {
    try {
      // Skapa en referens till det specifika dokumentet
      final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
      
      // Anropa .delete() för att ta bort det
      await docRef.delete();
    } catch (e) {
      print('Error deleting active workout state: $e');
      // Vi behöver inte nödvändigtvis kasta felet vidare här,
      // eftersom det inte är kritiskt för användaren om den här filen blir kvar.
    }
  }

  // Metod för att hitta den SENASTE sessionen som matchar en program-titel
Future<WorkoutSession?> findLastSessionOfProgram(String programTitle) async {
  try {
    // Skapa en referens till historik-collectionen
    final collectionRef = _db.collection('users').doc(uid).collection('workout_sessions');
    
    // Skapa en query:
    // 1. Filtrera för att bara hitta pass med rätt titel.
    // 2. Sortera efter datum i fallande ordning (nyast först).
    // 3. Begränsa resultatet till bara 1 dokument.
    final querySnapshot = await collectionRef
        .where('programTitle', isEqualTo: programTitle)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    // Om vi inte hittade något, returnera null
    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    // Annars, konvertera det första (och enda) dokumentet till ett objekt och returnera det
    return WorkoutSession.fromFirestore(querySnapshot.docs.first.data());

  } catch (e) {
    print("Error finding last session: $e");
    return null;
  }
}

  // STATISTIK METODER
  
  // Hämta alla träningspass för statistik
  Future<List<WorkoutSession>> getAllWorkoutSessions() async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('workout_sessions')
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => WorkoutSession.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print("Error fetching workout sessions: $e");
      return [];
    }
  }

  // Hämta träningspass för en specifik tidsperiod
  Future<List<WorkoutSession>> getWorkoutSessionsInPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('workout_sessions')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => WorkoutSession.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print("Error fetching workout sessions in period: $e");
      return [];
    }
  }

  // Räkna träningspass denna månad
  Future<int> getWorkoutsThisMonth() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    final sessions = await getWorkoutSessionsInPeriod(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
    
    return sessions.length;
  }

  // Räkna totala antal träningspass
  Future<int> getTotalWorkouts() async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('workout_sessions')
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Error counting total workouts: $e");
      return 0;
    }
  }

  // Räkna total träningstid i timmar
  Future<double> getTotalTrainingHours() async {
    final sessions = await getAllWorkoutSessions();
    final totalMinutes = sessions.fold<int>(
      0, 
      (sum, session) => sum + session.durationInMinutes,
    );
    return totalMinutes / 60.0;
  }

  // Hämta mest tränade program
  Future<Map<String, int>> getMostTrainedPrograms() async {
    final sessions = await getAllWorkoutSessions();
    final programCounts = <String, int>{};
    
    for (final session in sessions) {
      programCounts[session.programTitle] = 
          (programCounts[session.programTitle] ?? 0) + 1;
    }
    
    // Sortera efter antal träningar
    final sortedEntries = programCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Map.fromEntries(sortedEntries);
  }

  // Beräkna genomsnittlig träningstid
  Future<double> getAverageWorkoutDuration() async {
    final sessions = await getAllWorkoutSessions();
    if (sessions.isEmpty) return 0.0;
    
    final totalMinutes = sessions.fold<int>(
      0, 
      (sum, session) => sum + session.durationInMinutes,
    );
    
    return totalMinutes / sessions.length;
  }

  // PROGRESSION METODER FÖR GRAFER

  // Hämta alla unika övningsnamn från historiken
  Future<List<String>> getAllExerciseNames() async {
    final sessions = await getAllWorkoutSessions();
    final exerciseNames = <String>{};
    
    for (final session in sessions) {
      for (final exercise in session.completedExercises) {
        exerciseNames.add(exercise.name);
      }
    }
    
    return exerciseNames.toList()..sort();
  }

  // Hämta viktprogression för en specifik övning över tid
  Future<List<ProgressionDataPoint>> getExerciseProgression(String exerciseName) async {
    final sessions = await getAllWorkoutSessions();
    final progressionData = <ProgressionDataPoint>[];
    
    for (final session in sessions) {
      // Leta efter övningen i denna session
      final exercise = session.completedExercises
          .where((ex) => ex.name == exerciseName)
          .firstOrNull;
      
      if (exercise != null && exercise.sets.isNotEmpty) {
        // Hitta det tyngsta setet för denna övning i denna session (exklusive warm-up sets)
        final workingSets = exercise.sets.where((set) => !set.isWarmUp);
        if (workingSets.isNotEmpty) {
          final maxWeight = workingSets
              .map((set) => set.weight)
              .reduce((a, b) => a > b ? a : b);
        
          progressionData.add(
            ProgressionDataPoint(
              date: session.date,
              weight: maxWeight,
              sessionId: session.id,
            ),
          );
        }
      }
    }
    
    // Sortera efter datum (äldst först)
    progressionData.sort((a, b) => a.date.compareTo(b.date));
    
    return progressionData;
  }

  // Hämta volymprogression (weight * reps * sets) för en övning
  Future<List<VolumeDataPoint>> getExerciseVolumeProgression(String exerciseName) async {
    final sessions = await getAllWorkoutSessions();
    final volumeData = <VolumeDataPoint>[];
    
    for (final session in sessions) {
      final exercise = session.completedExercises
          .where((ex) => ex.name == exerciseName)
          .firstOrNull;
      
      if (exercise != null && exercise.sets.isNotEmpty) {
        // Beräkna total volym för denna övning i denna session (exklusive warm-up sets)
        double totalVolume = 0;
        for (final set in exercise.sets) {
          // Räkna bara working sets, inte warm-up sets
          if (!set.isWarmUp) {
            totalVolume += set.weight * set.reps;
          }
        }
        
        volumeData.add(
          VolumeDataPoint(
            date: session.date,
            volume: totalVolume,
            sessionId: session.id,
          ),
        );
      }
    }
    
    volumeData.sort((a, b) => a.date.compareTo(b.date));
    return volumeData;
  }

  // Hämta personliga rekord för alla övningar
  Future<Map<String, PersonalRecord>> getAllPersonalRecords() async {
    final exerciseNames = await getAllExerciseNames();
    final personalRecords = <String, PersonalRecord>{};
    
    for (final exerciseName in exerciseNames) {
      final progression = await getExerciseProgression(exerciseName);
      if (progression.isNotEmpty) {
        // Hitta det tyngsta lyftet för denna övning
        final maxWeightPoint = progression
            .reduce((a, b) => a.weight > b.weight ? a : b);
        
        personalRecords[exerciseName] = PersonalRecord(
          exerciseName: exerciseName,
          weight: maxWeightPoint.weight,
          date: maxWeightPoint.date,
          sessionId: maxWeightPoint.sessionId,
        );
      }
    }
    
    return personalRecords;
  }

  // MUSKELGRUPP STATISTIK METODER

  // Lista över alla muskelgrupper
  static const List<String> muscleGroups = [
    'Shoulders',
    'Quads', 
    'Hamstrings',
    'Glutes',
    'Calf',
    'Biceps',
    'Triceps',
    'Chest',
    'Back',
    'Abs',
  ];

  // Hämta alla MasterExercises för att koppla övningsnamn till muskelgrupper
  Future<Map<String, String>> getExerciseToMuscleGroupMap() async {
    try {
      final exerciseToMuscleGroup = <String, String>{};
      
      for (final muscleGroup in muscleGroups) {
        final snapshot = await _db
            .collection('users')
            .doc(uid)
            .collection('master_exercises')
            .where('category', isEqualTo: muscleGroup)  
            .get();
            
        for (final doc in snapshot.docs) {
          final exerciseData = doc.data();
          final exerciseName = exerciseData['name'] as String;
          exerciseToMuscleGroup[exerciseName] = muscleGroup;
        }
      }
      
      // Also check for legacy "Legs" category and map to "Quads"
      final legsSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('master_exercises')
          .where('category', isEqualTo: 'Legs')
          .get();
          
      for (final doc in legsSnapshot.docs) {
        final exerciseData = doc.data();
        final exerciseName = exerciseData['name'] as String;
        exerciseToMuscleGroup[exerciseName] = 'Quads'; // Map legacy "Legs" to "Quads"
      }
      
      // Migration: Handle legacy "Legs" category
      await _migrateLegsCategory();
      
      return exerciseToMuscleGroup;
    } catch (e) {
      print('Error fetching exercise to muscle group mapping: $e');
      return {};
    }
  }

  // Migration method to convert "Legs" to "Quads"
  Future<void> _migrateLegsCategory() async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('master_exercises')
          .where('category', isEqualTo: 'Legs')
          .get();
          
      for (final doc in snapshot.docs) {
        await doc.reference.update({'category': 'Quads'});
      }
    } catch (e) {
      print('Error migrating Legs category: $e');
    }
  }

  // Räkna sets per muskelgrupp från träningshistorik
  Future<Map<String, int>> getMuscleGroupSetCounts() async {
    try {
      final sessions = await getAllWorkoutSessions();
      final exerciseToMuscleGroup = await getExerciseToMuscleGroupMap();
      final muscleGroupCounts = <String, int>{};
      
      // Initialisera alla muskelgrupper med 0
      for (final muscleGroup in muscleGroups) {
        muscleGroupCounts[muscleGroup] = 0;
      }
      
      // Räkna sets för varje session
      for (final session in sessions) {
        for (final completedExercise in session.completedExercises) {
          final exerciseName = completedExercise.name;
          final muscleGroup = exerciseToMuscleGroup[exerciseName];
          
          if (muscleGroup != null) {
            // Räkna bara genomförda working sets (med weight > 0 och reps > 0)
            final completedWorkingSetsCount = completedExercise.sets
                .where((set) => !set.isWarmUp && set.weight > 0 && set.reps > 0)
                .length;
            muscleGroupCounts[muscleGroup] = 
                (muscleGroupCounts[muscleGroup] ?? 0) + completedWorkingSetsCount;
          }
        }
      }
      
      return muscleGroupCounts;
    } catch (e) {
      print('Error calculating muscle group set counts: $e');
      return {};
    }
  }

  // Räkna sets per muskelgrupp för en specifik tidsperiod
  Future<Map<String, int>> getMuscleGroupSetCountsInPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final sessions = await getWorkoutSessionsInPeriod(
        startDate: startDate,
        endDate: endDate,
      );
      final exerciseToMuscleGroup = await getExerciseToMuscleGroupMap();
      final muscleGroupCounts = <String, int>{};
      
      // Initialisera alla muskelgrupper med 0
      for (final muscleGroup in muscleGroups) {
        muscleGroupCounts[muscleGroup] = 0;
      }
      
      // Räkna sets för varje session i perioden
      for (final session in sessions) {
        for (final completedExercise in session.completedExercises) {
          final exerciseName = completedExercise.name;
          final muscleGroup = exerciseToMuscleGroup[exerciseName];
          
          if (muscleGroup != null) {
            // Räkna bara genomförda working sets (med weight > 0 och reps > 0)
            final completedWorkingSetsCount = completedExercise.sets
                .where((set) => !set.isWarmUp && set.weight > 0 && set.reps > 0)
                .length;
            muscleGroupCounts[muscleGroup] = 
                (muscleGroupCounts[muscleGroup] ?? 0) + completedWorkingSetsCount;
          }
        }
      }
      
      return muscleGroupCounts;
    } catch (e) {
      print('Error calculating muscle group set counts for period: $e');
      return {};
    }
  }

  // Hitta mest tränade muskelgrupper (sorterat)
  Future<List<MuscleGroupStat>> getMostTrainedMuscleGroups() async {
    final setCounts = await getMuscleGroupSetCounts();
    final stats = <MuscleGroupStat>[];
    
    for (final entry in setCounts.entries) {
      stats.add(MuscleGroupStat(
        muscleGroup: entry.key,
        setCount: entry.value,
      ));
    }
    
    // Sortera efter antal sets (högst först)
    stats.sort((a, b) => b.setCount.compareTo(a.setCount));
    
    return stats;
  }

  // Beräkna muskelgrupp fördelning i procent
  Future<Map<String, double>> getMuscleGroupPercentages() async {
    final setCounts = await getMuscleGroupSetCounts();
    final totalSets = setCounts.values.fold<int>(0, (sum, count) => sum + count);
    
    if (totalSets == 0) return {};
    
    final percentages = <String, double>{};
    for (final entry in setCounts.entries) {
      percentages[entry.key] = (entry.value / totalSets) * 100;
    }
    
    return percentages;
  }

  // Save standard workout as user's own workout
  Future<void> saveStandardWorkoutAsOwn(StandardWorkoutTemplate template) async {
    final workoutProgram = template.toWorkoutProgram();
    // Generate new ID for user's copy
    workoutProgram.id = _db.collection('users').doc(uid).collection('workout_programs').doc().id;
    
    // Save the workout program
    await saveWorkoutProgram(workoutProgram);
    
    // Also add all exercises to user's master exercises
    await _addExercisesToMasterExercises(workoutProgram.exercises);
  }

  // Helper method to add exercises to master exercises collection
  Future<void> _addExercisesToMasterExercises(List<Exercise> exercises) async {
    try {
      // Get existing master exercises to avoid duplicates
      final existingExercisesSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('master_exercises')
          .get();
      
      final existingExerciseNames = existingExercisesSnapshot.docs
          .map((doc) => doc.data()['name'] as String)
          .toSet();

      // Add new exercises that don't already exist
      for (final exercise in exercises) {
        if (!existingExerciseNames.contains(exercise.name)) {
          final masterExercise = MasterExercise(
            id: exercise.id,
            name: exercise.name,
            category: _getCategoryForExercise(exercise.name), // Helper to determine category
          );
          
          await saveMasterExercise(masterExercise);
        }
      }
    } catch (e) {
      print('Error adding exercises to master exercises: $e');
      // Don't throw error here - we still want the workout to be saved even if this fails
    }
  }

  // Helper method to determine category based on exercise name
  String _getCategoryForExercise(String exerciseName) {
    final name = exerciseName.toLowerCase();
    
    // Special cases first (before general rules)
    if (name.contains('reverse') && name.contains('pec')) {
      return 'Shoulders';
    }
    
    // Chest exercises
    if (name.contains('press') && (name.contains('chest') || name.contains('bench') || name.contains('incline'))) {
      return 'Chest';
    }
    if (name.contains('fly') || name.contains('pec')) {
      return 'Chest';
    }
    if (name.contains('push') && name.contains('up')) {
      return 'Chest';
    }
    
    // Back exercises
    if (name.contains('pull') || name.contains('row') || name.contains('lat')) {
      return 'Back';
    }
    if (name.contains('deadlift')) {
      return 'Back';
    }
    
    // Shoulder exercises
    if (name.contains('lateral') || name.contains('shoulder') || name.contains('overhead')) {
      return 'Shoulders';
    }
    
    // Biceps exercises
    if (name.contains('curl') || name.contains('bicep')) {
      return 'Biceps';
    }
    
    // Triceps exercises
    if (name.contains('tricep') || name.contains('extension') || name.contains('jm press')) {
      return 'Triceps';
    }
    if (name.contains('dip')) {
      return 'Triceps';
    }
    
    // Quads exercises
    if (name.contains('squat') || name.contains('leg press') || name.contains('extension')) {
      return 'Quads';
    }
    if (name.contains('lunge') && !name.contains('reverse')) {
      return 'Quads';
    }
    
    // Hamstrings exercises
    if (name.contains('deadlift') || name.contains('curl') && name.contains('leg')) {
      return 'Hamstrings';
    }
    if (name.contains('reverse') && name.contains('lunge')) {
      return 'Hamstrings';
    }
    
    // Glutes exercises
    if (name.contains('thrust') || name.contains('glute') || name.contains('hip')) {
      return 'Glutes';
    }
    
    // Calf exercises
    if (name.contains('calf') || name.contains('raise') && (name.contains('standing') || name.contains('seated'))) {
      return 'Calf';
    }
    
    // Abs exercises
    if (name.contains('plank') || name.contains('crunch') || name.contains('twist') || name.contains('abs')) {
      return 'Abs';
    }
    
    // Default to Chest if can't determine (most common in templates)
    return 'Chest';
  }

  // ACCOUNT DELETION METHODS

  /// Raderar all användardata från Firestore
  /// Detta inkluderar workout programs, sessions, master exercises, etc.
  Future<void> deleteAllUserData() async {
    try {
      final batch = _db.batch();
      
      // Radera workout programs
      final workoutPrograms = await _db
          .collection('users')
          .doc(uid)
          .collection('workout_programs')
          .get();
      for (final doc in workoutPrograms.docs) {
        batch.delete(doc.reference);
      }
      
      // Radera workout sessions
      final workoutSessions = await _db
          .collection('users')
          .doc(uid)
          .collection('workout_sessions')
          .get();
      for (final doc in workoutSessions.docs) {
        batch.delete(doc.reference);
      }
      
      // Radera master exercises
      final masterExercises = await _db
          .collection('users')
          .doc(uid)
          .collection('master_exercises')
          .get();
      for (final doc in masterExercises.docs) {
        batch.delete(doc.reference);
      }
      
      // Radera active session data
      final activeSession = await _db
          .collection('users')
          .doc(uid)
          .collection('active_session')
          .get();
      for (final doc in activeSession.docs) {
        batch.delete(doc.reference);
      }
      
      // Radera användarens huvud-dokument
      final userDoc = _db.collection('users').doc(uid);
      batch.delete(userDoc);
      
      // Utför alla raderingar i en batch
      await batch.commit();
      
      print('All user data deleted successfully');
    } catch (e) {
      print('Error deleting user data: $e');
      rethrow;
    }
  }

}

// Dataklasser för progression
class ProgressionDataPoint {
  final DateTime date;
  final double weight;
  final String sessionId;

  ProgressionDataPoint({
    required this.date,
    required this.weight,
    required this.sessionId,
  });
}

class VolumeDataPoint {
  final DateTime date;
  final double volume;
  final String sessionId;

  VolumeDataPoint({
    required this.date,
    required this.volume,
    required this.sessionId,
  });
}

class PersonalRecord {
  final String exerciseName;
  final double weight;
  final DateTime date;
  final String sessionId;

  PersonalRecord({
    required this.exerciseName,
    required this.weight,
    required this.date,
    required this.sessionId,
  });
}

class MuscleGroupStat {
  final String muscleGroup;
  final int setCount;

  MuscleGroupStat({
    required this.muscleGroup,
    required this.setCount,
  });
}

// Static methods for standard workout templates (no uid needed)
class StandardWorkoutService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get all standard workout templates
  static Stream<List<StandardWorkoutTemplate>> getStandardWorkouts() {
    return _db
        .collection('standard_workouts')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return StandardWorkoutTemplate.fromMap(doc.data());
      }).toList();
    });
  }

  // Admin method to add standard workout (you would use this to populate data)
  static Future<void> addStandardWorkout(StandardWorkoutTemplate template) async {
    try {
      await _db
          .collection('standard_workouts')
          .doc(template.id)
          .set(template.toMap());
    } catch (e) {
      print('Error adding standard workout: $e');
      rethrow;
    }
  }


}

