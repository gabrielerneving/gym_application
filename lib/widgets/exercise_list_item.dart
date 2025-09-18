import 'package:flutter/material.dart';
import '../models/exercise_model.dart'; // Se till att sökvägen till din modell är korrekt

class ExerciseListItem extends StatelessWidget {
  // Denna widget tar emot ett Exercise-objekt för att veta vad den ska visa.
  final Exercise exercise;

  const ExerciseListItem({
    Key? key,
    required this.exercise,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Color(0xFF18181B), // Mörkgrå färg som i din design
      margin: const EdgeInsets.symmetric(vertical: 8.0), // Lite utrymme mellan varje item
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0), // Rundade hörn
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
        title: Text(
          exercise.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${exercise.sets} set',
          style: TextStyle(
            color: Colors.grey.shade400,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.more_vert, // De tre prickarna
            color: Colors.white,
          ),
          onPressed: () {
            // Här kan du lägga till logik för vad som händer när man trycker,
            // t.ex. visa en meny för att redigera eller ta bort.
            print('Menu button for ${exercise.name} pressed');
          },
        ),
      ),
    );
  }
}