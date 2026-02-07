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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientText(
              text: 'Workout history',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 34,
              ),
              currentThemeIndex: ref.watch(themeIndexProvider),
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
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: workoutHistory.length,
                    itemBuilder: (context, index) {
                      return WorkoutHistoryWidget(
                        key: ValueKey(workoutHistory[index].id),
                        session: workoutHistory[index],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}