import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_session_model.dart';
import '../services/database_service.dart';
import '../widgets/workout_history_widget.dart'; // Eller vad din card-widget heter
import '../widgets/gradient_text.dart';
import '../providers/theme_provider.dart';

class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  // Använder nu Firebase istället för hårdkodad data
  int _selectedIndex = 2; // Index för bottom nav bar

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(body: Center(child: Text("Not logged in.", style: TextStyle(color: theme.text))));
    }

    final dbService = DatabaseService(uid: uid);

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.background,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 80,
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: GradientText(
                    text: 'Workout history',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 34,
                    ),
                    currentThemeIndex: ref.watch(themeIndexProvider),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<WorkoutSession>>(
                  stream: dbService.getWorkoutSessions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          "Your workout history is empty.\nComplete a workout to see it here!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.textSecondary, fontSize: 16),
                        ),
                      );
                    }

                    final workoutHistory = snapshot.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 100), // Extra padding för navbar
                      itemCount: workoutHistory.length,
                      itemBuilder: (context, index) {
                        return WorkoutHistoryWidget(session: workoutHistory[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              height: 65,
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: theme.text.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_outlined, 0),
                  _buildNavItem(Icons.fitness_center_outlined, 1),
                  _buildNavItem(Icons.history, 2), // Detta är den aktiva
                  _buildNavItem(Icons.bar_chart_outlined, 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bygger en enskild ikon i botten-menyn
  Widget _buildNavItem(IconData icon, int index) {
    final theme = ref.read(themeProvider);
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
          color: isSelected ? theme.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? theme.text : theme.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}