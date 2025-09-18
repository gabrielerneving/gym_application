import 'package:flutter/material.dart';

class PopularWorkoutsCard extends StatelessWidget {
  // Vi förväntar oss en Map där nyckeln är träningspassets namn och värdet är antalet gånger det körts.
  final Map<String, int> popularWorkouts;

  const PopularWorkoutsCard({Key? key, required this.popularWorkouts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hitta det högsta värdet för att kunna räkna ut progress-baren proportionerligt
    final int maxCount = popularWorkouts.values.fold(0, (prev, element) => element > prev ? element : prev);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most popular workouts',
            style: TextStyle(
              color: Colors.white,
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
              progress: maxCount > 0 ? entry.value / maxCount : 0.0,
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                // Custom progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade800,
                    color: Colors.redAccent,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}