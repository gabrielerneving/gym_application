import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class PopularWorkoutsCard extends ConsumerWidget {
  // Vi förväntar oss en Map där nyckeln är träningspassets namn och värdet är antalet gånger det körts.
  final Map<String, int> popularWorkouts;

  const PopularWorkoutsCard({Key? key, required this.popularWorkouts}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    // Beräkna totalt antal workouts för att visa relativ andel
    final int totalWorkouts = popularWorkouts.values.fold(0, (prev, element) => prev + element);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Most popular workouts',
            style: TextStyle(
              color: theme.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Skapa en lista av rader baserat på vår map
          ...popularWorkouts.entries.map((entry) {
            return _buildPopularWorkoutRow(
              title: entry.key,
              count: entry.value,
              progress: totalWorkouts > 0 ? entry.value / totalWorkouts : 0.0,
              theme: theme,
            );
          }).toList(),
        ],
      ),
    );
  }

  // En privat hjälp-widget för att bygga en enskild rad
  Widget _buildPopularWorkoutRow({
    required String title,
    required int count,
    required double progress,
    required dynamic theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: theme.text, fontSize: 16)),
                const SizedBox(height: 8),
                // Custom progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.backgroundDark,
                    color: theme.primary,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            count.toString(),
            style: TextStyle(
              color: theme.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}