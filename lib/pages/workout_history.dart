import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_session_model.dart';
import '../services/database_service.dart';
import '../widgets/workout_history_widget.dart'; // Eller vad din card-widget heter

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  // Ta bort den hårdkodade listan helt och hållet
  // final List<WorkoutSession> _workoutHistory = [ ... ];

  int _selectedIndex = 2; // Index för din bottom nav bar

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in.")));
    }

    final dbService = DatabaseService(uid: uid);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Huvudinnehåll
          Column(
            children: [
              // AppBar-området
              Container(
                height: 80,
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                child: const Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Workout history',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Lista med träningshistorik
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
                      return const Center(
                        child: Text(
                          "Your workout history is empty.\nComplete a workout to see it here!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }

                    final workoutHistory = snapshot.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 100), // Extra bottom padding för navbar
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

          // Flytande navbar
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              height: 65,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
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