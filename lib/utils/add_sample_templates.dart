import '../models/standard_workout_template.dart';
import '../services/database_service.dart';

// Hjälpfunktion för att lägga till exempel-templates
// Kör denna en gång för att fylla databasen med standard templates
Future<void> addSampleTemplates() async {
  // Template 1: Upper Body
  final upperBodyTemplate = StandardWorkoutTemplate(
    id: 'Upper Body',
    title: 'Upper Body Workout',
    description: 'A focused workout for the upper body, targeting arms, back, shoulders, and chest.',
    category: 'Everyne',
    type: 'Upper Body',
    estimatedDurationMinutes: 60,
    createdBy: 'Official',
    exercises: [
      StandardExercise(
        name: 'Bicep curls',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Focus on keeping good form throughout the movement and find a comfortable range of motion to standardize your workout.',
      ),
      StandardExercise(
        name: 'Tricep extensions',
        sets: 3,
        workingSets: 2,
        warmUpSets: 3,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Focus on keeping good form throughout the movement and find a comfortable range of motion to standardize your workout. Dont let the back take over the movement.',
      ),
      StandardExercise(
        name: 'Chest Press',
        sets: 3,
        workingSets: 2,
        warmUpSets: 2,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Focus on keeping good form throughout the movement and find a comfortable range of motion to standardize your workout. You do not have to lock out each time since it will be a lot of tricep work.',
      ),
      StandardExercise(
        name: 'Lat Pulldown',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Find a good range of motion, for example bar to eyes or chin. Do not swing too much, keep it in the frontal plane.',
      ),
      StandardExercise(
        name: 'Lateral Raises',
        sets: 3,
        workingSets: 3,
        warmUpSets: 0,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Do not shrug so mucht that the traps take over.',
      ),
      StandardExercise(
        name: 'Kelso Shrugs',
        sets: 2,
        workingSets: 1,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. The range of motion may be small, do not worry. Make sure to retract the scapula.',
      ),
    ],
  );

 

  // Template 5: Legs Focus
  final legsTemplate = StandardWorkoutTemplate(
    id: 'legs-focus-1',
    title: 'Legs Focus Workout',
    description: 'Comprehensive leg training targeting quads, hamstrings, glutes, and calves with machine and bodyweight exercises.',
    category: 'Intermediate',
    type: 'Lower Body',
    estimatedDurationMinutes: 70,
    createdBy: 'Official',
    exercises: [
      StandardExercise(
        name: 'Leg Extensions',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Focus on controlled movement and full range of motion. Keep your back pressed against the pad.',
      ),
      StandardExercise(
        name: 'Leg Curls',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Control the negative portion and squeeze hamstrings at the top. Avoid using momentum.',
      ),
      StandardExercise(
        name: 'Seated Leg Curls',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Adjust seat position for optimal range of motion. Focus on hamstring isolation.',
      ),
      StandardExercise(
        name: 'Sissy Squat',
        sets: 3,
        workingSets: 3,
        warmUpSets: 0,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Advanced exercise - lean back while squatting, focus on quad stretch. Use support if needed.',
      ),
      StandardExercise(
        name: 'Back Extension',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Focus on posterior chain activation. Control the movement and avoid hyperextension.',
      ),
      StandardExercise(
        name: 'Calf Raise',
        sets: 3,
        workingSets: 3,
        warmUpSets: 0,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Full range of motion - stretch at bottom, squeeze at top. Control the tempo.',
      ),
    ],
  );

  // Template 6: Push Day
  final pushTemplate = StandardWorkoutTemplate(
    id: 'push-day-1',
    title: 'Push Day Workout',
    description: 'Complete push day focusing on chest, shoulders, and triceps. Perfect for push/pull/legs split routine.',
    category: 'Intermediate',
    type: 'Upper Body',
    estimatedDurationMinutes: 65,
    createdBy: 'Official',
    exercises: [
      StandardExercise(
        name: 'Incline Machine Press',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Focus on upper chest activation. Control the weight and avoid locking out completely.',
      ),
      StandardExercise(
        name: 'Pec Deck Fly',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Focus on chest stretch and squeeze. Keep slight bend in elbows throughout movement.',
      ),
      StandardExercise(
        name: 'Lateral Raise',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Target middle deltoids. Avoid using traps - keep shoulders down and controlled.',
      ),
      StandardExercise(
        name: 'JM Press',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Hybrid between close-grip bench and skull crusher. Focus on tricep isolation.',
      ),
      StandardExercise(
        name: 'Tricep Extension',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Full range of motion for tricep activation. Keep elbows stable throughout movement.',
      ),
    ],
  );

  // Template 7: Pull Day
  final pullTemplate = StandardWorkoutTemplate(
    id: 'pull-day-1',
    title: 'Pull Day Workout',
    description: 'Complete pull day targeting back, rear delts, and biceps. Perfect complement to push day in split routine.',
    category: 'Intermediate',
    type: 'Upper Body',
    estimatedDurationMinutes: 65,
    createdBy: 'Official',
    exercises: [
      StandardExercise(
        name: 'Upper Back Row',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Focus on upper back and rear delt activation. Squeeze shoulder blades together.',
      ),
      StandardExercise(
        name: 'Lat Pulldown',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Target lats with controlled movement. Pull to chest/chin level, avoid swinging.',
      ),
      StandardExercise(
        name: 'Reverse Peck Deck',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Target rear delts and upper back. Focus on squeezing shoulder blades together.',
      ),
      StandardExercise(
        name: 'Preacher Curl',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Strict bicep isolation. Control negative and avoid using momentum.',
      ),
      StandardExercise(
        name: 'Seated Bicep Curls',
        sets: 3,
        workingSets: 2,
        warmUpSets: 1,
        notes: 'Aim for 4-9 reps, 2-3 min rest. Seated position for stability. Focus on bicep peak contraction at top.',
      ),
    ],
  );

  try {
    // Lägg till alla templates
    await StandardWorkoutService.addStandardWorkout(upperBodyTemplate);
    await StandardWorkoutService.addStandardWorkout(legsTemplate);
    await StandardWorkoutService.addStandardWorkout(pushTemplate);
    await StandardWorkoutService.addStandardWorkout(pullTemplate);
    
    print('✅ Successfully added all 4 workout templates!');
  } catch (e) {
    print('❌ Error adding templates: $e');
  }
}