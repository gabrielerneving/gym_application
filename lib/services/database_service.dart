import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/workout_model.dart';
import '../models/master_exercise_model.dart';
import '../models/exercise_model.dart';
import '../models/workout_session_model.dart';
import '../models/standard_workout_template.dart';

/// Firestore access for one user.
///
/// This is deliberately CRUD-only. Everything derived — volume, streaks,
/// progression, 1RM, muscle balance — lives in `services/analytics_service.dart`
/// and runs against a single cached fetch of the session history. The
/// statistics helpers that used to live here re-read the whole
/// `workout_sessions` collection once per exercise, and had their own slightly
/// different idea of what counted as a working set. Do not add derived metrics
/// back into this class.
class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _legacyCategoryMigrationDone = false;

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
      debugPrint('Error saving workout program: $e');
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
    debugPrint('Error deleting workout program: $e');
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
    debugPrint('Error updating workout program: $e');
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
    debugPrint('Error saving workout session: $e');
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
  final placeholders = data['placeholders'];
  if (placeholders is Map) {
    return Map<String, dynamic>.from(placeholders);
  }
  return <String, dynamic>{};
}

// Spara starttid för träningspass
Future<void> saveActiveStartTime(DateTime startTime) async {
  final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
  await docRef.set({'startTime': startTime.toIso8601String()}, SetOptions(merge: true));
}

// Ladda starttid för träningspass
Future<DateTime?> loadActiveStartTime() async {
  final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
  final snapshot = await docRef.get();
  if (!snapshot.exists) return null;
  final data = snapshot.data();
  if (data == null) return null;
  final startTimeStr = data['startTime'];
  if (startTimeStr is String) {
    try {
      return DateTime.parse(startTimeStr);
    } catch (e) {
      return null;
    }
  }
  return null;
}

 // Metod för att ta bort det temporära "pågående pass"-dokumentet
  Future<void> deleteActiveWorkoutState() async {
    try {
      // Skapa en referens till det specifika dokumentet
      final docRef = _db.collection('users').doc(uid).collection('active_session').doc('current');
      
      // Anropa .delete() för att ta bort det
      await docRef.delete();
    } catch (e) {
      debugPrint('Error deleting active workout state: $e');
      // Vi behöver inte nödvändigtvis kasta felet vidare här,
      // eftersom det inte är kritiskt för användaren om den här filen blir kvar.
    }
  }

  // Metod för att radera ett träningspass från historiken
  Future<void> deleteWorkoutSession(String sessionId) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('workout_sessions')
          .doc(sessionId)
          .delete();
      debugPrint('Workout session deleted successfully: $sessionId');
    } catch (e) {
      debugPrint('Error deleting workout session: $e');
      rethrow;
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
    debugPrint("Error finding last session: $e");
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
      debugPrint("Error fetching workout sessions: $e");
      return [];
    }
  }


  // MUSKELGRUPP STATISTIK METODER

  // Lista över alla muskelgrupper
  static const List<String> muscleGroups = [
    'Shoulders',
    'Quads', 
    'Hamstrings',
    'Glutes',
    'Calves',
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
      
      // Läs in kategorinamn som appen inte längre använder, så att gamla
      // övningar fortfarande räknas i statistiken.
      for (final entry in legacyCategoryAliases.entries) {
        final snapshot = await _db
            .collection('users')
            .doc(uid)
            .collection('master_exercises')
            .where('category', isEqualTo: entry.key)
            .get();

        for (final doc in snapshot.docs) {
          final exerciseData = doc.data();
          final exerciseName = exerciseData['name'] as String;
          exerciseToMuscleGroup[exerciseName] = entry.value;
        }
      }

      // Migration: Run only once per app session to avoid repeated writes on every read
      if (!_legacyCategoryMigrationDone) {
        await _migrateLegacyCategories();
        _legacyCategoryMigrationDone = true;
      }

      return exerciseToMuscleGroup;
    } catch (e) {
      debugPrint('Error fetching exercise to muscle group mapping: $e');
      return {};
    }
  }

  /// Kategorinamn som har använts tidigare, och vad de heter idag.
  ///
  /// Nycklarna får ALDRIG tas bort: en övning som ligger kvar under ett gammalt
  /// namn hittas annars inte av `muscleGroups`-frågorna, och all träning för den
  /// muskelgruppen försvinner tyst ur statistiken.
  static const Map<String, String> legacyCategoryAliases = {
    'Legs': 'Quads',
    'Calf': 'Calves',
  };

  // Skriver om gamla kategorinamn till de nuvarande.
  Future<void> _migrateLegacyCategories() async {
    for (final entry in legacyCategoryAliases.entries) {
      try {
        final snapshot = await _db
            .collection('users')
            .doc(uid)
            .collection('master_exercises')
            .where('category', isEqualTo: entry.key)
            .get();

        for (final doc in snapshot.docs) {
          await doc.reference.update({'category': entry.value});
        }
      } catch (e) {
        debugPrint('Error migrating ${entry.key} category: $e');
      }
    }
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
      debugPrint('Error adding exercises to master exercises: $e');
      // Don't throw error here - we still want the workout to be saved even if this fails
    }
  }

  // Helper method to determine category based on exercise name
  String _getCategoryForExercise(String exerciseName) {
    final name = exerciseName.toLowerCase();
    
    // === SPECIFIKA FALL FÖRST (undvik felklassificering) ===
    
    // Leg Curl / Leg Extension måste fångas innan generella curl/extension-regler
    if (name.contains('leg') && name.contains('curl')) return 'Hamstrings';
    if (name.contains('leg') && name.contains('extension')) return 'Quads';
    if (name.contains('hamstring')) return 'Hamstrings';
    
    // Reverse pec deck = Shoulders
    if (name.contains('reverse') && name.contains('pec')) return 'Shoulders';
    
    // Chest exercises
    if (name.contains('press') && (name.contains('chest') || name.contains('bench') || name.contains('incline') || name.contains('decline'))) {
      return 'Chest';
    }
    if (name.contains('fly') || name.contains('flye') || name.contains('pec')) return 'Chest';
    if (name.contains('push') && name.contains('up')) return 'Chest';
    
    // Back exercises
    if (name.contains('pull') && (name.contains('up') || name.contains('down'))) return 'Back';
    if (name.contains('row') || name.contains('lat ')) return 'Back';
    if (name.contains('deadlift') && !name.contains('romanian') && !name.contains('rdl') && !name.contains('stiff')) return 'Back';
    
    // Hamstrings (RDL, Romanian, stiff-leg)
    if (name.contains('romanian') || name.contains('rdl') || name.contains('stiff')) return 'Hamstrings';
    if (name.contains('reverse') && name.contains('lunge')) return 'Hamstrings';
    
    // Shoulder exercises
    if (name.contains('lateral') || name.contains('shoulder') || name.contains('overhead') || name.contains('military')) {
      return 'Shoulders';
    }
    if (name.contains('face') && name.contains('pull')) return 'Shoulders';
    if (name.contains('rear') && name.contains('delt')) return 'Shoulders';
    
    // Biceps exercises (efter leg curl-check)
    if (name.contains('curl') || name.contains('bicep') || name.contains('hammer')) return 'Biceps';
    
    // Triceps exercises (efter leg extension-check)
    if (name.contains('tricep') || name.contains('pushdown') || name.contains('skull') || name.contains('jm press')) {
      return 'Triceps';
    }
    if (name.contains('extension') && !name.contains('leg') && !name.contains('back')) return 'Triceps';
    if (name.contains('dip')) return 'Triceps';
    
    // Quads exercises
    if (name.contains('squat') || name.contains('leg press')) return 'Quads';
    if (name.contains('lunge') && !name.contains('reverse')) return 'Quads';
    
    // Glutes exercises
    if (name.contains('thrust') || name.contains('glute') || name.contains('hip')) return 'Glutes';
    
    // Calf exercises — must return 'Calves' to match `muscleGroups`, otherwise
    // the sets land in a category nothing queries and vanish from statistics.
    if (name.contains('calf') || (name.contains('raise') && (name.contains('standing') || name.contains('seated')))) {
      return 'Calves';
    }
    
    // Abs exercises
    if (name.contains('plank') || name.contains('crunch') || name.contains('twist') || name.contains('abs') || name.contains('sit') && name.contains('up')) {
      return 'Abs';
    }
    
    // Default
    return 'Chest';
  }

  // ACCOUNT DELETION METHODS

  /// Raderar all användardata från Firestore
  /// Detta inkluderar workout programs, sessions, master exercises, etc.
  Future<void> deleteAllUserData() async {
    try {
      // Samla alla dokument som ska raderas
      final allDocs = <DocumentReference>[];
      
      // Radera workout programs
      final workoutPrograms = await _db
          .collection('users')
          .doc(uid)
          .collection('workout_programs')
          .get();
      allDocs.addAll(workoutPrograms.docs.map((d) => d.reference));
      
      // Radera workout sessions
      final workoutSessions = await _db
          .collection('users')
          .doc(uid)
          .collection('workout_sessions')
          .get();
      allDocs.addAll(workoutSessions.docs.map((d) => d.reference));
      
      // Radera master exercises
      final masterExercises = await _db
          .collection('users')
          .doc(uid)
          .collection('master_exercises')
          .get();
      allDocs.addAll(masterExercises.docs.map((d) => d.reference));
      
      // Radera active session data
      final activeSession = await _db
          .collection('users')
          .doc(uid)
          .collection('active_session')
          .get();
      allDocs.addAll(activeSession.docs.map((d) => d.reference));
      
      // Radera användarens huvud-dokument
      allDocs.add(_db.collection('users').doc(uid));
      
      // Chunk i batchar av max 400 (Firestore limit är 500)
      for (int i = 0; i < allDocs.length; i += 400) {
        final batch = _db.batch();
        final end = (i + 400 < allDocs.length) ? i + 400 : allDocs.length;
        for (int j = i; j < end; j++) {
          batch.delete(allDocs[j]);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error deleting user data: $e');
      rethrow;
    }
  }

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
      debugPrint('Error adding standard workout: $e');
      rethrow;
    }
  }


}

