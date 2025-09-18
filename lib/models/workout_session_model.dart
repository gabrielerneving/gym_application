import 'exercise_model.dart'; // Vi återanvänder Exercise-modellen!

class WorkoutSession {
  final String id;
  final String programTitle; // t.ex. "Upper 1"
  final DateTime date; // Datumet då passet utfördes
  final int durationInMinutes; // t.ex. 65
  final List<Exercise> completedExercises; // Lista över övningarna som gjordes

  // Enkel getter för att få totalt antal unika övningar
  int get exerciseCount => completedExercises.length;

  WorkoutSession({
    required this.id,
    required this.programTitle,
    required this.date,
    required this.durationInMinutes,
    required this.completedExercises,
  });
}