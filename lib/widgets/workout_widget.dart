import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import 'gradient_button.dart';

class WorkoutWidget extends ConsumerWidget {
  final String title;
  final String description;
  final int exerciseCount;
  final VoidCallback onMenuPressed;
  final VoidCallback? onStartWorkout;
  final VoidCallback? onTap;

  const WorkoutWidget({
    Key? key,
    required this.title,
    required this.description,
    required this.exerciseCount,
    required this.onMenuPressed,
    this.onStartWorkout,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final themeIndex = ref.watch(themeIndexProvider);
    final isPinkMode = themeIndex == 1; // Pink theme is at index 1
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
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
          GradientButton(
            text: 'Start workout',
            onPressed: onStartWorkout ?? () {},
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            borderRadius: 20,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      ),
    );
  }
}