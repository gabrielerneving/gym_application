import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_model.dart'; // Importera din modell
import '../models/master_exercise_model.dart'; // Importera din MasterExercise-modell

class DatabaseService {
  // Hämta en instans av Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // En referens till den specifika användarens data
  final String uid;
  DatabaseService({required this.uid});

  // Metod för att spara ett nytt träningsprogram
  Future<void> saveWorkoutProgram(WorkoutProgram program) async {
    try {
      // Vi skapar en datastruktur:
      // users -> {userId} -> workout_programs -> {programId} -> {programdata}
      
      // Skapa en referens till collectionen för den här användarens träningsprogram
      final collectionRef = _db.collection('users').doc(uid).collection('workout_programs');

      // Använd program.id som dokument-ID
      await collectionRef.doc(program.id).set({
        'title': program.title,
        'id': program.id,
        // Vi måste konvertera listan med övningar till ett format Firestore förstår (en lista av Maps)
        'exercises': program.exercises.map((exercise) => {
          'id': exercise.id,
          'name': exercise.name,
          'sets': exercise.sets,
        }).toList(),
      });
    } catch (e) {
      print('Error saving workout program: $e');
      // Här kan du kasta ett eget fel om du vill hantera det i UI:t
      rethrow;
    }
  }

// Metod för att hämta en STREAM av träningsprogram
Stream<List<WorkoutProgram>> getWorkoutPrograms() {
  final collectionRef = _db.collection('users').doc(uid).collection('workout_programs');

  // Lyssna på ändringar i collectionen
  return collectionRef.snapshots().map((snapshot) {
    // För varje "snapshot" (ny version av datan), konvertera varje dokument
    // till ett WorkoutProgram-objekt.
    return snapshot.docs.map((doc) {
      // Vi behöver en metod i vår modell för att konvertera Firestore-data till ett objekt
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
}

