import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/workout_model.dart';
import '../models/workout_session_model.dart'; // Importera den uppdaterade modellen
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final WorkoutProgram program;
  const ActiveWorkoutScreen({Key? key, required this.program}) : super(key: key);

  @override
  _ActiveWorkoutScreenState createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late Timer _timer;
  int _elapsedSeconds = 0;
  int _currentExerciseIndex = 0;

  // En Map för att hålla all inmatad data
  // Struktur: { exerciseIndex -> { setIndex -> { 'weight': value, 'reps': value } } }
  late Map<int, Map<int, Map<String, double>>> _workoutData;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initializeWorkoutData();
  }

  // Initierar vår datastruktur med tomma värden
  void _initializeWorkoutData() {
    _workoutData = {};
    for (int i = 0; i < widget.program.exercises.length; i++) {
      _workoutData[i] = {};
      for (int j = 0; j < widget.program.exercises[i].sets; j++) {
        _workoutData[i]![j] = {'weight': 0.0, 'reps': 0};
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  // Snygg formatering för timern
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer.cancel(); // Mycket viktigt för att undvika minnesläckor!
    super.dispose();
  }

  void _goToNextExercise() {
    if (_currentExerciseIndex < widget.program.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
      });
    }
  }

  void _goToPreviousExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
      });
    }
  }

  Future<void> _finishWorkout() async {
    _timer.cancel();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 1. Konvertera vår _workoutData Map till en lista av CompletedExercise
    List<CompletedExercise> completedExercises = [];
    _workoutData.forEach((exerciseIndex, setData) {
      List<CompletedSet> completedSets = [];
      setData.forEach((setIndex, data) {
        completedSets.add(CompletedSet(
          weight: data['weight']!,
          reps: data['reps']!.toInt(),
        ));
      });
      completedExercises.add(CompletedExercise(
        name: widget.program.exercises[exerciseIndex].name,
        sets: completedSets,
      ));
    });

    // 2. Skapa ett WorkoutSession-objekt
    final session = WorkoutSession(
      id: const Uuid().v4(),
      programTitle: widget.program.title,
      date: DateTime.now(),
      durationInMinutes: (_elapsedSeconds / 60).ceil(),
      completedExercises: completedExercises,
    );

    // 3. Spara till databasen
    await DatabaseService(uid: uid).saveWorkoutSession(session);

    // 4. Navigera tillbaka och visa ett meddelande
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout finished and saved to history!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentExercise = widget.program.exercises[_currentExerciseIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.program.title),
        centerTitle: true,
        backgroundColor: Colors.black,
        // Visa timern i AppBar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Text(
            "Time: ${_formatDuration(_elapsedSeconds)}",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Visa aktuell övning
            Text(
              currentExercise.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Lista med inmatningsfält för sets
            Expanded(
              child: ListView.builder(
                itemCount: currentExercise.sets,
                itemBuilder: (context, setIndex) {
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
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'kg'),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (value) {
                                _workoutData[_currentExerciseIndex]![setIndex]!['weight'] = double.tryParse(value) ?? 0.0;
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Reps'),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                               onChanged: (value) {
                                _workoutData[_currentExerciseIndex]![setIndex]!['reps'] = double.tryParse(value) ?? 0.0;
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

            // Navigationsknappar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentExerciseIndex > 0 ? _goToPreviousExercise : null,
                  child: const Text('Previous'),
                ),
                ElevatedButton(
                  onPressed: _currentExerciseIndex < widget.program.exercises.length - 1 ? _goToNextExercise : null,
                  child: const Text('Next'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Avsluta-knapp
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finishWorkout,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Finish Workout', style: TextStyle(fontSize: 18)),
              ),
            )
          ],
        ),
      ),
    );
  }
}