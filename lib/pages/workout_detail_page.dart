import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/workout_session_model.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';

class WorkoutDetailPage extends ConsumerWidget {
  final WorkoutSession session;

  const WorkoutDetailPage({Key? key, required this.session}) : super(key: key);

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
          session.programTitle,
          style: TextStyle(
            color: theme.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
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
                    DateFormat('EEEE, MMMM d, yyyy').format(session.date),
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
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: '${session.durationInMinutes} min',
                        theme: theme,
                      ),
                      _buildStatItem(
                        icon: Icons.fitness_center,
                        label: 'Exercises',
                        value: '${session.completedExercises.length}',
                        theme: theme,
                      ),
                      _buildStatItem(
                        icon: Icons.repeat,
                        label: 'Working Sets',
                        value: '${session.completedExercises.fold<int>(0, (sum, ex) => sum + ex.sets.where((set) => !set.isWarmUp).length)}',
                        theme: theme,
                      ),
                      _buildStatItem(
                        icon: Icons.local_fire_department,
                        label: 'Warm-up Sets',
                        value: '${session.completedExercises.fold<int>(0, (sum, ex) => sum + ex.sets.where((set) => set.isWarmUp).length)}',
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
            
            ...session.completedExercises.asMap().entries.map((entry) {
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
                            color: theme.primary, // Använd tema-färg istället
                            borderRadius: BorderRadius.circular(8), // Lite mer rundning
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
                          child: Text(
                            exercise.name,
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Sets list
                    ...exercise.sets.asMap().entries.map((setEntry) {
                      final setIndex = setEntry.key;
                      final set = setEntry.value;
                      
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
                                color: set.isWarmUp 
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: set.isWarmUp 
                                  ? Border.all(color: Colors.orange.withOpacity(0.4), width: 1)
                                  : null,
                              ),
                              child: Center(
                                child: set.isWarmUp
                                  ? Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 12,
                                    )
                                  : Text(
                                      '${setIndex + 1}',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Weight
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
                                    set.weight > 0 ? '${set.weight} kg' : '-',
                                    style: TextStyle(
                                      color: theme.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Reps
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
                                    set.reps > 0 ? '${set.reps}' : '-',
                                    style: TextStyle(
                                      color: theme.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // RIR (conditionally shown)
                            if (ref.watch(workoutSettingsProvider).showRIR && set.rir != null && set.rir! > 0)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RIR',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${set.rir}',
                                      style: TextStyle(
                                        color: theme.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // Notes
                            if (set.notes != null && set.notes!.isNotEmpty)
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
                                      set.notes!,
                                      style: TextStyle(
                                        color: theme.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
    required theme,
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