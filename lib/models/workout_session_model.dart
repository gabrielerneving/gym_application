import 'package:cloud_firestore/cloud_firestore.dart';

import 'exercise_model.dart'; // Vi återanvänder Exercise-modellen!
// Vi skapar en liten hjälpklass för att representera ett slutfört set
class CompletedSet {
  final double weight;
  final int reps;
  final String? notes; // NYTT: Lägg till ett valfritt fält för anteckningar

  CompletedSet({required this.weight, required this.reps, this.notes});

  // copyWith metod för att skapa uppdaterade kopior
  CompletedSet copyWith({double? weight, int? reps, String? notes}) {
    return CompletedSet(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      notes: notes ?? this.notes,
    );
  }

  // Metod för att konvertera till en Map för Firestore
  Map<String, dynamic> toMap() {
    return {'weight': weight, 'reps': reps, 'notes': notes};
  }

  factory CompletedSet.fromMap(Map<String, dynamic> data) {
  return CompletedSet(
    weight: data['weight'] != null ? (data['weight'] as num).toDouble() : 0.0,
    reps: data['reps'] ?? 0,
    notes: data['notes'], // Kan vara null, det är okej
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

   CompletedExercise copyWith({String? name, List<CompletedSet>? sets}) {
    return CompletedExercise(name: name ?? this.name, sets: sets ?? this.sets);
  }

  factory CompletedExercise.fromMap(Map<String, dynamic> data) {
  var setsList = data['sets'] as List<dynamic>? ?? <dynamic>[];
  List<CompletedSet> sets = setsList.map((s) => CompletedSet.fromMap(s as Map<String, dynamic>)).toList();
  return CompletedExercise(name: data['name'] ?? '', sets: sets);
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
  var exercisesList = data['completedExercises'] as List<dynamic>? ?? <dynamic>[];
  List<CompletedExercise> exercises = exercisesList.map((e) => CompletedExercise.fromMap(e as Map<String, dynamic>)).toList();

  return WorkoutSession(
    id: data['id'] ?? '',
    programTitle: data['programTitle'] ?? '',
    // Firestore sparar Timestamps, vi måste konvertera dem till DateTime
    date: data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
    durationInMinutes: data['durationInMinutes'] ?? 0,
    completedExercises: exercises,
  );
}

WorkoutSession copyWith({
  String? id,
  String? programTitle,
  DateTime? date,
  int? durationInMinutes,
  List<CompletedExercise>? completedExercises,
}) {
  return WorkoutSession(
    id: id ?? this.id,
    programTitle: programTitle ?? this.programTitle,
    date: date ?? this.date,
    durationInMinutes: durationInMinutes ?? this.durationInMinutes,
    completedExercises: completedExercises ?? this.completedExercises,
  );
}
}