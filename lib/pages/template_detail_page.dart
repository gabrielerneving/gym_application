import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/standard_workout_template.dart';
import '../providers/theme_provider.dart';

class TemplateDetailPage extends ConsumerWidget {
  final StandardWorkoutTemplate template;

  const TemplateDetailPage({Key? key, required this.template}) : super(key: key);

  void _showExerciseDetails(BuildContext context, StandardExercise exercise, dynamic theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping on the sheet itself
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.8,
              builder: (_, controller) => Container(
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(20),
                child: ListView(
                  controller: controller,
                  children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Exercise name
              Text(
                exercise.name,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Muscle groups chips
              if (exercise.muscleGroups != null && exercise.muscleGroups!.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: exercise.muscleGroups!.map((muscle) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        muscle,
                        style: TextStyle(
                          color: theme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              
              const SizedBox(height: 20),
              
              // Sets info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sets & Reps',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      theme,
                      Icons.local_fire_department,
                      'Warm-up sets',
                      '${exercise.warmUpSets}',
                      Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      theme,
                      Icons.fitness_center,
                      'Working sets',
                      '${exercise.workingSets}',
                      theme.primary,
                    ),
                  ],
                ),
              ),
              
              // Notes
              if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: theme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Training Tips',
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        exercise.notes!,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(dynamic theme, IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: theme.text,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primary.withOpacity(0.8)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          template.title,
          style: TextStyle(
            color: theme.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.description,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(theme, Icons.category, template.type),
                      const SizedBox(width: 8),
                      _buildInfoChip(theme, Icons.schedule, '${template.estimatedDurationMinutes} min'),
                      const SizedBox(width: 8),
                      _buildInfoChip(theme, Icons.fitness_center, '${template.exercises.length} exercises'),
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
            
            // Exercises list
            ...template.exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Exercise number
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Exercise info
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
                            '${exercise.workingSets} sets${exercise.warmUpSets > 0 ? " + ${exercise.warmUpSets} warm-up" : ""}',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Info button
                    IconButton(
                      onPressed: () => _showExerciseDetails(context, exercise, theme),
                      icon: Icon(
                        Icons.info_outline,
                        color: theme.primary,
                        size: 24,
                      ),
                      tooltip: 'View exercise details',
                    ),
                  ],
                ),
              );
            }).toList(),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(dynamic theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
