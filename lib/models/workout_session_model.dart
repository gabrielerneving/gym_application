import 'package:cloud_firestore/cloud_firestore.dart';

class CompletedSet {
  final double weight;
  final int reps;
  final String? notes; 
  final bool isWarmUp;
  final int? rir; // Reps in Reserve - optional field
  final int? progression; // Progression jämfört med föregående pass (ex: +2 reps eller -1 reps)

  CompletedSet({
    required this.weight, 
    required this.reps, 
    this.notes,
    this.isWarmUp = false, // Default är working set
    this.rir, // Optional RIR value
    this.progression, // Optional progression indicator
  });

  // copyWith metod för att skapa uppdaterade kopior, användbar för immutability vilket innebär att objekt inte ändras direkt utan en ny kopia skapas med ändringar
  CompletedSet copyWith({double? weight, int? reps, String? notes, bool? isWarmUp, int? rir, int? progression}) {
    return CompletedSet(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      notes: notes ?? this.notes,
      isWarmUp: isWarmUp ?? this.isWarmUp,
      rir: rir ?? this.rir,
      progression: progression ?? this.progression,
    );
  }

  // Metod för att konvertera till en Map för Firestore
  Map<String, dynamic> toMap() {
    return {
      'weight': weight, 
      'reps': reps, 
      'notes': notes,
      'isWarmUp': isWarmUp,
      'rir': rir, // Include RIR in save
      'progression': progression, // Include progression in save
    };
  }

  factory CompletedSet.fromMap(Map<String, dynamic> data) {
    return CompletedSet(
      weight: data['weight'] != null ? (data['weight'] as num).toDouble() : 0.0,
      reps: data['reps'] ?? 0,
      notes: data['notes'], 
      isWarmUp: data['isWarmUp'] ?? false,
      rir: data['rir'], // Load RIR if available
      progression: data['progression'], // Load progression if available
    );
  }
}

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



class WorkoutSession {
  final String id;
  final String programTitle;
  final DateTime date;
  final int durationInMinutes;
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