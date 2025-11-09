import 'package:uuid/uuid.dart';
import 'workout_model.dart';
import 'exercise_model.dart';

class StandardWorkoutTemplate {
  final String id;
  final String title;
  final String description;
  final List<StandardExercise> exercises;
  final String category; // e.g., "Beginner", "Intermediate", "Advanced"
  final String type; // e.g., "Push Pull Legs", "Upper Lower", "Full Body"
  final int estimatedDurationMinutes;
  final String createdBy; // "Official" or developer name

  StandardWorkoutTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.exercises,
    required this.category,
    required this.type,
    required this.estimatedDurationMinutes,
    this.createdBy = "Official",
  });

  // Convert to regular WorkoutProgram when user saves it
  WorkoutProgram toWorkoutProgram() {
    return WorkoutProgram(
      id: '', // Will be generated when saved
      title: title,
      exercises: exercises.map((e) => e.toExercise()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'category': category,
      'type': type,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'createdBy': createdBy,
    };
  }

  factory StandardWorkoutTemplate.fromMap(Map<String, dynamic> map) {
    return StandardWorkoutTemplate(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      exercises: (map['exercises'] as List<dynamic>?)
          ?.map((e) => StandardExercise.fromMap(e))
          .toList() ?? [],
      category: map['category'] ?? '',
      type: map['type'] ?? '',
      estimatedDurationMinutes: map['estimatedDurationMinutes'] ?? 60,
      createdBy: map['createdBy'] ?? 'Official',
    );
  }
}

class StandardExercise {
  final String name;
  final int sets;
  final int workingSets;
  final int warmUpSets;
  final String? notes; // Optional training notes like "Focus on form"
  final String? imageUrl; // URL to exercise demonstration image/gif
  final List<String>? muscleGroups; // Target muscles like ["Chest", "Triceps"]

  StandardExercise({
    required this.name,
    required this.sets,
    required this.workingSets,
    required this.warmUpSets,
    this.notes,
    this.imageUrl,
    this.muscleGroups,
  });

  Exercise toExercise() {
    return Exercise(
      id: const Uuid().v4(),
      name: name,
      sets: sets,
      workingSets: workingSets,
      warmUpSets: warmUpSets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': sets,
      'workingSets': workingSets,
      'warmUpSets': warmUpSets,
      'notes': notes,
      'imageUrl': imageUrl,
      'muscleGroups': muscleGroups,
    };
  }

  factory StandardExercise.fromMap(Map<String, dynamic> map) {
    return StandardExercise(
      name: map['name'] ?? '',
      sets: map['sets'] ?? 1,
      workingSets: map['workingSets'] ?? 1,
      warmUpSets: map['warmUpSets'] ?? 0,
      notes: map['notes'],
      imageUrl: map['imageUrl'],
      muscleGroups: map['muscleGroups'] != null 
          ? List<String>.from(map['muscleGroups']) 
          : null,
    );
  }
}