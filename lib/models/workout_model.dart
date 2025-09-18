import 'exercise_model.dart'; // Importera din Exercise-modell

class WorkoutProgram {
  String title;
  List<Exercise> exercises; // Byt ut exerciseCount mot en lista
  String id;

  // Enkel getter för att få antalet övningar
  int get exerciseCount => exercises.length;

  WorkoutProgram({
    required this.title,
    required this.exercises,
    required this.id,
  });
}