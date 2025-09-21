import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_provider.dart'; // Importera vår nya provider

// ÄNDRING 1: Byt från StatefulWidget till ConsumerWidget
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({Key? key}) : super(key: key);

  // Vi behöver inte längre ta emot ett program, eftersom vi läser det från providern.

  // En hjälpmetod för att visa bekräftelsedialogen
  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave workout?'),
        content: const Text('Your progress will be saved. You can resume later from the home screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  // ÄNDRING 2: build-metoden tar nu emot en WidgetRef
  Widget build(BuildContext context, WidgetRef ref) {
    // ÄNDRING 3: Läs det aktuella statet från providern.
    // .watch() gör att skärmen automatiskt byggs om när statet ändras.
    final activeWorkoutState = ref.watch(workoutProvider);
    final session = activeWorkoutState.session;

    // Om inget pass är igång (t.ex. om användaren navigerar hit via en länk av misstag),
    // visa ett felmeddelande.
    if (session == null || !activeWorkoutState.isRunning) {
      return const Scaffold(
        body: Center(child: Text('No active workout found.')),
      );
    }

    // Snygg formatering för timern
    String formatDuration(int totalSeconds) {
      final duration = Duration(seconds: totalSeconds);
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }

    // ÄNDRING 4: Använd WillPopScope för att hantera "tillbaka"-knappen
    return WillPopScope(
      onWillPop: () async {
        final shouldLeave = await _showExitConfirmationDialog(context);
        if (shouldLeave) {
          // Anropa notifiern för att pausa passet
          ref.read(workoutProvider.notifier).pauseWorkout();
        }
        return shouldLeave; // Returnera true för att tillåta navigering
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.programTitle),
          centerTitle: true,
          backgroundColor: Colors.black,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            // ÄNDRING 5: Läs tiden från providern
            child: Text(
              "Time: ${formatDuration(activeWorkoutState.elapsedSeconds)}",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // Lista med alla övningar (tog bort timer header)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: session.completedExercises.length,
                itemBuilder: (context, exerciseIndex) {
                  final exercise = session.completedExercises[exerciseIndex];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Övningsnamn med bokstav
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + exerciseIndex), // A, B, C, etc.
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                exercise.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Sets
                        ...exercise.sets.asMap().entries.map((entry) {
                          final setIndex = entry.key;
                          final set = entry.value;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                // Set nummer
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${setIndex + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Weight input
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Weight',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextFormField(
                                        initialValue: set.weight > 0 ? set.weight.toString() : '',
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade600),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade600),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFDC2626)),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        onChanged: (value) {
                                          final weight = double.tryParse(value) ?? 0.0;
                                          ref.read(workoutProvider.notifier).updateSetData(
                                            exerciseIndex, setIndex, weight, set.reps
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Reps input
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Reps',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextFormField(
                                        initialValue: set.reps > 0 ? set.reps.toString() : '',
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade600),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade600),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFDC2626)),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        onChanged: (value) {
                                          final reps = int.tryParse(value) ?? 0;
                                          ref.read(workoutProvider.notifier).updateSetData(
                                            exerciseIndex, setIndex, set.weight, reps
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Notes input
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Notes',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextFormField(
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade600),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey.shade600),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFDC2626)),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Finish workout button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(workoutProvider.notifier).finishWorkout();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Finish Workout',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}