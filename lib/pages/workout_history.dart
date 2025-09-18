import 'package:flutter/material.dart';
import '../models/exercise_model.dart';
import '../models/workout_session_model.dart';
import '../widgets/workout_history_widget.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  // Exempeldata som matchar din design
  final List<WorkoutSession> _workoutHistory = [
    WorkoutSession(
      id: 'ws1',
      programTitle: 'Upper 1',
      date: DateTime(2025, 9, 25), // Antar ett datum
      durationInMinutes: 65,
      completedExercises: [
        Exercise(name: 'Bicep curls', sets: 2, id: 'ex1'),
        Exercise(name: 'Reverse curls', sets: 1, id: 'ex2'),
        Exercise(name: 'Tricep extensions', sets: 2, id: 'ex3'),
        Exercise(name: 'Bicep curls', sets: 2, id: 'ex4'),
        Exercise(name: 'Reverse curls', sets: 1, id: 'ex5'),
        Exercise(name: 'Tricep extensions', sets: 2, id: 'ex6'),
        Exercise(name: 'Reverse curls', sets: 1, id: 'ex7'),
        Exercise(name: 'Tricep extensions', sets: 2, id: 'ex8'),
      ],
    ),
    WorkoutSession(
      id: 'ws2',
      programTitle: 'Upper 2',
      date: DateTime(2025, 9, 22), // Antar ett datum
      durationInMinutes: 65,
      completedExercises: [
        Exercise(name: 'Bicep curls', sets: 2, id: 'ex1'),
        Exercise(name: 'Reverse curls', sets: 1, id: 'ex2'),
        Exercise(name: 'Tricep extensions', sets: 2, id: 'ex3'),
        Exercise(name: 'Bicep curls', sets: 2, id: 'ex4'),
        Exercise(name: 'Reverse curls', sets: 1, id: 'ex5'),
        Exercise(name: 'Tricep extensions', sets: 2, id: 'ex6'),
        Exercise(name: 'Reverse curls', sets: 1, id: 'ex7'),
        Exercise(name: 'Tricep extensions', sets: 2, id: 'ex8'),
      ],
    ),
  ];

  int _selectedIndex = 2; // Index 2 är den aktiva "profil"-ikonen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 80, // Ger lite mer utrymme
        title: const Text(
          'Workout history',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 34,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _workoutHistory.length,
        itemBuilder: (context, index) {
          return WorkoutHistoryWidget(session: _workoutHistory[index]);
        },
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  // Widget för den anpassade botten-menyn
  Widget _buildCustomBottomNav() {
    return Container(
      margin: const EdgeInsets.all(16), // Marginal runt hela
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_outlined, 0),
          _buildNavItem(Icons.fitness_center_outlined, 1),
          _buildNavItem(Icons.person_outline, 2), // Detta är den aktiva
          _buildNavItem(Icons.settings_outlined, 3),
        ],
      ),
    );
  }

  // Bygger en enskild ikon i botten-menyn
  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.shade600,
          size: 28,
        ),
      ),
    );
  }
}