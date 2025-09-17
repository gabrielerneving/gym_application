import 'package:flutter/material.dart';
import '../widgets/workout_widget.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onSwitchToProfileTab;
  const HomeScreen({Key? key, this.onSwitchToProfileTab}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: const Color.fromARGB(255, 0, 0, 0),
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 8.0),
            child: Text(
              'My workouts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Text(
              '2 workouts saved',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                WorkoutWidget(
                  title: 'Upper 1',
                  description: 'Bicep curls, reverse curls, Tri...',
                  exerciseCount: 7,
                  onDelete: () {
                    // Hantera delete
                  },
                  onStartWorkout: () {
                    // Hantera start workout
                  },
                ),
                WorkoutWidget(
                  title: 'Upper 2',
                  description: 'Bicep curls, reverse curls, Tri...',
                  exerciseCount: 10,
                  onDelete: () {
                    // Hantera delete
                  },
                  onStartWorkout: () {
                    // Hantera start workout
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  } 
}
