import 'exercise_model.dart'; 

class WorkoutProgram {
  String title;
  List<Exercise> exercises; 
  String id;

  // Enkel getter för att få antalet övningar
  int get exerciseCount => exercises.length;

  WorkoutProgram({
    required this.title,
    required this.exercises,
    required this.id,
  });

  // Skapar ett WorkoutProgram från Firestore-data (en Map)
  factory WorkoutProgram.fromFirestore(Map<String, dynamic> data) {
    // Konvertera listan av exercise-maps från Firestore tillbaka till en lista av Exercise-objekt
    var exercisesList = data['exercises'] as List;
    List<Exercise> exercises = exercisesList.map((exerciseData) => Exercise.fromMap(exerciseData)).toList();

    return WorkoutProgram(
      id: data['id'] ?? '',
      title: data['title'] ?? 'No Title',
      exercises: exercises,
    );
  }
}