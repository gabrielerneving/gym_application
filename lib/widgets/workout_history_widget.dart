import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import '../models/workout_session_model.dart';
import '../pages/workout_detail_page.dart';

class WorkoutHistoryWidget extends ConsumerWidget {
  final WorkoutSession session;

  const WorkoutHistoryWidget({Key? key, required this.session}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
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
                        style: const TextStyle(
                          color: Colors.white, // Tillbaka till vit för titel
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(session.date),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Höger sida - kompakta stats
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
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.durationInMinutes}m',
                            style: TextStyle(
                              color: Colors.grey.shade300,
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
                          color: Colors.grey.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade600,
                      size: 16,
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
                color: Colors.grey.shade400,
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
                    color: Colors.grey.shade500,
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