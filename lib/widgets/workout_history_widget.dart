import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
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
            // Header row med titel och stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Vänster sida - titel och datum
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
                    ],
                  ),
                ),
                
                // Höger sida - kompakta stats och meny
                Row(
                  children: [
                    // Timer chip - Subtle style
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: theme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.durationInMinutes}m',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Exercises count - Subtle style
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${session.completedExercises.length}',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Papperskorgs-ikon för att radera workout
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.textSecondary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showDeleteDialog(context, ref, theme),
                    ),
                  ],
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