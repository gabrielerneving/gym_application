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

    // Vi behöver en PageController för att hantera bytet mellan övningar
    final pageController = PageController(initialPage: 0); // Vi kan göra detta mer avancerat senare

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
        body: PageView.builder(
          controller: pageController,
          itemCount: session.completedExercises.length,
          itemBuilder: (context, exerciseIndex) {
            final currentExercise = session.completedExercises[exerciseIndex];
            
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    currentExercise.name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: currentExercise.sets.length,
                      itemBuilder: (context, setIndex) {
                        final currentSet = currentExercise.sets[setIndex];
                        return Card(
                          color: Colors.grey.shade900,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Set ${setIndex + 1}", style: const TextStyle(fontSize: 18)),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    initialValue: currentSet.weight > 0 ? currentSet.weight.toString() : '',
                                    decoration: const InputDecoration(labelText: 'kg'),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    onChanged: (value) {
                                      // ÄNDRING 6: Anropa notifiern för att uppdatera data
                                      final weight = double.tryParse(value) ?? 0.0;
                                      ref.read(workoutProvider.notifier).updateSetData(
                                        exerciseIndex, setIndex, weight, currentSet.reps
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    initialValue: currentSet.reps > 0 ? currentSet.reps.toString() : '',
                                    decoration: const InputDecoration(labelText: 'Reps'),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    onChanged: (value) {
                                       // ÄNDRING 7: Anropa notifiern för att uppdatera data
                                      final reps = int.tryParse(value) ?? 0;
                                      ref.read(workoutProvider.notifier).updateSetData(
                                        exerciseIndex, setIndex, currentSet.weight, reps
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // ÄNDRING 8: Anropa notifiern för att avsluta passet
                        await ref.read(workoutProvider.notifier).finishWorkout();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Finish Workout', style: TextStyle(fontSize: 18)),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}