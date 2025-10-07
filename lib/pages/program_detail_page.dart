import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_model.dart';
import '../providers/theme_provider.dart';
import 'create_workout.dart';

class ProgramDetailPage extends ConsumerWidget {
  final WorkoutProgram program;

  const ProgramDetailPage({Key? key, required this.program}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primary.withOpacity(0.8), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          program.title,
          style: TextStyle(
            color: theme.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: const Color(0xFFDC2626).withOpacity(0.8), size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateWorkoutScreen(workoutToEdit: program),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.textSecondary.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Program Overview',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        icon: Icons.fitness_center,
                        label: 'Exercises',
                        value: '${program.exercises.length}',
                        theme: theme,
                      ),
                      _buildStatItem(
                        icon: Icons.repeat,
                        label: 'Total Sets',
                        value: '${program.exercises.fold<int>(0, (sum, ex) => sum + ex.sets)}',
                        theme: theme,
                      ),
                       _buildStatItem(
                        icon: Icons.repeat,
                        label: 'Working Sets',
                        value: '${program.exercises.fold<int>(0, (sum, ex) => sum + ex.workingSets)}',
                        theme: theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Text(
              'Exercises',
              style: TextStyle(
                color: theme.text,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ...program.exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.textSecondary.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercise header
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index), // A, B, C...
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.name,
                                style: TextStyle(
                                  color: theme.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                exercise.warmUpSets > 0 
                                  ? '${exercise.workingSets} working + ${exercise.warmUpSets} warm-up sets'
                                  : '${exercise.sets} sets planned',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Empty sets template
                    ...List.generate(exercise.sets, (setIndex) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Set number with warm-up indication
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: setIndex < exercise.warmUpSets
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: setIndex < exercise.warmUpSets
                                  ? Border.all(color: Colors.orange.withOpacity(0.4), width: 1)
                                  : null,
                              ),
                              child: Center(
                                child: setIndex < exercise.warmUpSets
                                  ? Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 12,
                                    )
                                  : Text(
                                      '${setIndex - exercise.warmUpSets + 1}',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Set type label
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    setIndex < exercise.warmUpSets ? 'Warm-up' : 'Working',
                                    style: TextStyle(
                                      color: setIndex < exercise.warmUpSets ? Colors.orange : theme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    setIndex < exercise.warmUpSets 
                                      ? 'Set ${setIndex + 1}'
                                      : 'Set ${setIndex - exercise.warmUpSets + 1}',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Empty placeholders for weight/reps/notes
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weight',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '—',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reps',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '—',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notes',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '—',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required dynamic theme,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: theme.text,
          size: 26,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: theme.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}