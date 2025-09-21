import 'package:cloud_firestore/cloud_firestore.dart';

import 'exercise_model.dart'; // Vi återanvänder Exercise-modellen!
// Vi skapar en liten hjälpklass för att representera ett slutfört set
class CompletedSet {
  final double weight;
  final int reps;

  CompletedSet({required this.weight, required this.reps});

  // Metod för att konvertera till en Map för Firestore
  Map<String, dynamic> toMap() {
    return {'weight': weight, 'reps': reps};
  }

  factory CompletedSet.fromMap(Map<String, dynamic> data) {
  return CompletedSet(
    weight: (data['weight'] as num).toDouble(),
    reps: data['reps'],
  );
}
}

// Vi uppdaterar den här klassen också
class CompletedExercise {
  final String name;
  final List<CompletedSet> sets;

  CompletedExercise({required this.name, required this.sets});

  Map<String, dynamic> toMap() {
    return {'name': name, 'sets': sets.map((s) => s.toMap()).toList()};
  }

  factory CompletedExercise.fromMap(Map<String, dynamic> data) {
  var setsList = data['sets'] as List;
  List<CompletedSet> sets = setsList.map((s) => CompletedSet.fromMap(s)).toList();
  return CompletedExercise(name: data['name'], sets: sets);
}

}



// Huvudmodellen för sessionen
class WorkoutSession {
  final String id;
  final String programTitle;
  final DateTime date;
  final int durationInMinutes;
  // ÄNDRAD: Använder vår nya, mer detaljerade modell
  final List<CompletedExercise> completedExercises;

  WorkoutSession({
    required this.id,
    required this.programTitle,
    required this.date,
    required this.durationInMinutes,
    required this.completedExercises,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'programTitle': programTitle,
      'date': date,
      'durationInMinutes': durationInMinutes,
      'completedExercises': completedExercises.map((e) => e.toMap()).toList(),
    };
  }
  factory WorkoutSession.fromFirestore(Map<String, dynamic> data) {
  var exercisesList = data['completedExercises'] as List;
  List<CompletedExercise> exercises = exercisesList.map((e) => CompletedExercise.fromMap(e)).toList();

  return WorkoutSession(
    id: data['id'],
    programTitle: data['programTitle'],
    // Firestore sparar Timestamps, vi måste konvertera dem till DateTime
    date: (data['date'] as Timestamp).toDate(),
    durationInMinutes: data['durationInMinutes'],
    completedExercises: exercises,
  );
}
}