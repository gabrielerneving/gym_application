import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/workout_model.dart';
import '../services/database_service.dart';
import '../widgets/workout_widget.dart'; // Din befintliga widget

class HomeScreen extends StatelessWidget {
  final VoidCallback? onSwitchToProfileTab;
  const HomeScreen({Key? key, this.onSwitchToProfileTab}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // NYTT: Hämta den inloggade användarens unika ID
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Säkerhetskoll ifall något skulle gå fel och vi inte har ett UID
    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text("Could not find user. Please log in again."),
        ),
      );
    }

    // NYTT: Skapa en instans av vår DatabaseService
    final dbService = DatabaseService(uid: uid);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
        // NYTT: StreamBuilder för att hämta och visa data i realtid
        child: StreamBuilder<List<WorkoutProgram>>(
          stream: dbService.getWorkoutPrograms(),
          builder: (context, snapshot) {
            // Medan vi väntar på data från Firebase, visa en laddningsindikator
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Om ett fel inträffade
            if (snapshot.hasError) {
              return Center(child: Text("Something went wrong: ${snapshot.error}"));
            }

            // Om vi har data, men listan är tom
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(); // Anropar en snyggare "tom" vy
            }

            // Om vi har data!
            final programs = snapshot.data!;

            // Detta är din befintliga UI-struktur, nu med dynamisk data
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My workouts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // ÄNDRAT: Visar det faktiska antalet sparade pass
                Text(
                  '${programs.length} workouts saved',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  // ÄNDRAT: Använder ListView.builder för att effektivt bygga listan
                  child: ListView.builder(
                    itemCount: programs.length,
                    itemBuilder: (context, index) {
                      final program = programs[index];
                      // Skapa en kort beskrivning från de första övningarna
                      final description = program.exercises
                          .map((e) => e.name)
                          .take(3)
                          .join(', ');

                      // Använder din befintliga WorkoutWidget!
                      return WorkoutWidget(
                        title: program.title,
                        description: '$description...',
                        exerciseCount: program.exercises.length,
                        onDelete: () {
                          // Här kommer vi lägga till logik för att ta bort ett pass
                        },
                        onStartWorkout: () {
                          // Här kommer vi lägga till logik för att starta ett pass
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // En hjälp-widget för att visa ett meddelande när inga pass finns
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, color: Colors.grey, size: 60),
          SizedBox(height: 16),
          Text(
            'No Workouts Yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the "Create" button to add your first workout!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}