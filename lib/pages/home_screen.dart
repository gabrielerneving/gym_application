import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_app/pages/active_workout_screen.dart';
import '../models/workout_model.dart';
import '../services/database_service.dart';
import '../widgets/workout_widget.dart'; 
import '../providers/workout_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../pages/program_detail_page.dart';
import '../widgets/gradient_text.dart';
import 'create_workout.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onSwitchToProfileTab;
  const HomeScreen({Key? key, this.onSwitchToProfileTab}) : super(key: key);

Future<bool> _showDeleteConfirmationDialog(BuildContext context, String programTitle) async {
  // visa en dialog och vänta på användarens svar
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Are you sure you want to delete "$programTitle"? This action cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), 
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
  // Om användaren avfärdar dialogen (klickar utanför), returnera false
  return result ?? false;
}

void _showActiveWorkoutDialog(BuildContext context, AppColors theme) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: theme.card,
        title: Text(
          'Workout Already Active',
          style: TextStyle(color: theme.text),
        ),
        content: Text(
          'You already have an active workout in progress. Please finish or cancel your current workout before starting a new one.',
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: theme.primary),
            ),
          ),
        ],
      );
    },
  );
}

void _showWorkoutOptions(BuildContext context, WorkoutProgram program, DatabaseService dbService) {
  showModalBottomSheet(
    context: context,
    builder: (bc) {
      return SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(context).pop(); 
                // Navigera till CreateWorkoutScreen och skicka med programmet
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => CreateWorkoutScreen(workoutToEdit: program),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(context).pop(); 
                final shouldDelete = await _showDeleteConfirmationDialog(context, program.title);
                if (shouldDelete) {
                  await dbService.deleteWorkoutProgram(program.id);
                }
              },
            ),
          ],
        ),
      );
    },
  );
}



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Säkerhetskoll ifall något skulle gå fel och vi inte har ett UID
    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text("Could not find user. Please log in again."),
        ),
      );
    }

    // Skapa en instans av vår DatabaseService
    final dbService = DatabaseService(uid: uid);

    return Scaffold(
      backgroundColor: theme.background,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 50, 16, 60), 
        // StreamBuilder för att hämta och visa data i realtid
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
              return _buildEmptyState(theme); // Anropar en snyggare "tom" vy
            }

            // Om vi har data
            final programs = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  text: 'My workouts',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                  currentThemeIndex: ref.watch(themeIndexProvider),
                ),
                // Visar det faktiska antalet sparade pass
                Text(
                  '${programs.length} workouts saved',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  // Använder ListView.builder för att effektivt bygga listan
                  child: ListView.builder(
                    itemCount: programs.length,
                    itemBuilder: (context, index) {
                      final program = programs[index];
                      // Skapa en kort beskrivning från de första övningarna
                      final description = program.exercises
                          .map((e) => e.name)
                          .take(3)
                          .join(', ');

                      // Använder befintliga WorkoutWidget!
                      return WorkoutWidget(
                        title: program.title,
                        description: '$description...',
                        exerciseCount: program.exercises.length,
                        onMenuPressed: () {
                          _showWorkoutOptions(context, program, dbService);
                        },
                        onStartWorkout: () {
                          // Kontrollera om ett workout redan pågår
                          final activeWorkout = ref.read(workoutProvider);
                          if (activeWorkout.isRunning) {
                            _showActiveWorkoutDialog(context, theme);
                            return;
                          }
                          
                          ref.read(workoutProvider.notifier).startWorkout(program);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const ActiveWorkoutScreen(),
                          ));
                        },
                        onTap: () {
                          // Visa program struktur utan tidigare data
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProgramDetailPage(program: program),
                            ),
                          );
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
  Widget _buildEmptyState(AppColors theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, color: theme.textSecondary, size: 60),
          const SizedBox(height: 16),
          Text(
            'No Workouts Yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.text),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the "Create" button to add your first workout!',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}