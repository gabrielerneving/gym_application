import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_session_model.dart';

class WorkoutHistoryWidget extends StatelessWidget {
  final WorkoutSession session;

  const WorkoutHistoryWidget({Key? key, required this.session}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF18181B), // En specifik mörkgrå färg
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(
      color: Color(0xFF4C4C4C), // grå border
      width: 1,                 // tjocklek på border
    ),),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.programTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM d').format(session.date),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${session.durationInMinutes} min',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.completedExercises.length} exercises',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...session.completedExercises.map((exercise) {
              // Skapa en textsträng för varje set
              final setsDetails = exercise.sets.map((set) {
                return '  - ${set.weight} kg x ${set.reps} reps';
              }).join('\n'); // Lägg till en ny rad mellan varje set

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  '${exercise.name}\n$setsDetails', // Visa övningens namn följt av set-detaljerna
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 15, height: 1.5),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}