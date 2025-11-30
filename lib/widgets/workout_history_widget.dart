import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../models/workout_session_model.dart';
import '../pages/workout_detail_page.dart';
import '../services/database_service.dart';

class WorkoutHistoryWidget extends ConsumerWidget {
  final WorkoutSession session;

  const WorkoutHistoryWidget({Key? key, required this.session}) : super(key: key);

  void _showDeleteDialog(BuildContext context, WidgetRef ref, dynamic theme) {
    HapticFeedback.mediumImpact(); // Haptic när dialogen öppnas
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Workout',
            style: TextStyle(color: theme.text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete this workout? This action cannot be undone.',
            style: TextStyle(color: theme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.heavyImpact(); // Starkare haptic för delete
                Navigator.of(dialogContext).pop();
                await _deleteWorkout(context);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWorkout(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final dbService = DatabaseService(uid: uid);
      await dbService.deleteWorkoutSession(session.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting workout: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool _hasProgression() {
    for (final exercise in session.completedExercises) {
      for (final set in exercise.sets) {
        if ((set.progression != null && set.progression != 0) ||
            (set.weightProgression != null && set.weightProgression != 0)) {
          return true;
        }
      }
    }
    return false;
  }

  List<Widget> _buildProgressionIndicators(dynamic theme) {
    final indicators = <Widget>[];
    
    for (final exercise in session.completedExercises) {
      for (final set in exercise.sets) {
        // Rep progression indicator
        if (set.progression != null && set.progression != 0) {
          final isPositive = set.progression! > 0;
          indicators.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isPositive 
                  ? Colors.green.withOpacity(0.15) 
                  : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isPositive ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${set.progression} reps',
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        
        // Weight progression indicator
        if (set.weightProgression != null && set.weightProgression != 0) {
          final isPositive = set.weightProgression! > 0;
          final color = isPositive ? theme.primary : Colors.orange;
          indicators.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: color,
                  width: 1,
                ),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${set.weightProgression!.toStringAsFixed(1)} kg',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
      }
    }
    
    return indicators;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final themeIndex = ref.watch(themeIndexProvider);
    final isPinkMode = themeIndex == 1; // Pink theme is at index 1
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutDetailPage(session: session),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12), // Mindre rundning för Android-stil
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isPinkMode ? [
            BoxShadow(
              color: const Color(0xFFFCE7F3),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row med titel och delete-ikon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vänster sida - titel, datum och stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.programTitle,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(session.date),
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Stats chips under datumet
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Timer chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 12,
                                  color: theme.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${session.durationInMinutes}m',
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Exercises count
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fitness_center,
                                  size: 12,
                                  color: theme.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${session.completedExercises.length}',
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Progression chips direkt efter
                          if (ref.watch(workoutSettingsProvider).showProgression && _hasProgression())
                            ..._buildProgressionIndicators(theme),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Höger sida - bara delete-ikon
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showDeleteDialog(context, ref, theme),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Övningar preview - bara namnen
            Text(
              session.completedExercises.take(3).map((e) => e.name).join(' • '),
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            if (session.completedExercises.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${session.completedExercises.length - 3} more',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}