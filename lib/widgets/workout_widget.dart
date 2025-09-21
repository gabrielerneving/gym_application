import 'package:flutter/material.dart';

class WorkoutWidget extends StatelessWidget {
  final String title;
  final String description;
  final int exerciseCount;
  final VoidCallback onMenuPressed;
  final VoidCallback? onStartWorkout;

  const WorkoutWidget({
    Key? key,
    required this.title,
    required this.description,
    required this.exerciseCount,
    required this.onMenuPressed,
    this.onStartWorkout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey),
                onPressed: onMenuPressed, // Anropa callbacken när den trycks
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.fitness_center, color: Colors.grey, size: 18),
              const SizedBox(width: 4),
              Text(
                '$exerciseCount exercises',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onStartWorkout,
              child: const Text(
                'Start workout',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),

              ),
            ),
          ),
        ],
      ),
    );
  }
}