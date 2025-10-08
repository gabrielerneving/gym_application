import '../models/standard_workout_template.dart';
import '../services/database_service.dart';

// Exempel på hur du skapar en egen template
Future<void> addCustomTemplate() async {
  final myTemplate = StandardWorkoutTemplate(
    id: 'my-custom-workout-1',
    title: 'Min Egen Workout',
    description: 'En anpassad workout som jag har skapat själv.',
    category: 'Custom', // Beginner, Intermediate, Advanced, Custom
    type: 'Full Body', // Full Body, Upper Body, Lower Body, Push Pull Legs, HIIT, etc.
    estimatedDurationMinutes: 30,
    createdBy: 'Your Name', // Ditt namn eller "Official"
    exercises: [
      StandardExercise(
        name: 'Squats',
        sets: 3,
        workingSets: 3,
        warmUpSets: 1,
        notes: 'Viktad squat, 8-10 reps, 90s vila',
      ),
      StandardExercise(
        name: 'Push-ups',
        sets: 3,
        workingSets: 3,
        warmUpSets: 0,
        notes: 'Vanliga armhävningar, 10-15 reps, 60s vila',
      ),
      // Lägg till fler övningar...
    ],
  );

  try {
    await StandardWorkoutService.addStandardWorkout(myTemplate);
    print('✅ Template added successfully!');
  } catch (e) {
    print('❌ Error: $e');
  }
}