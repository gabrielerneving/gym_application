import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise_model.dart'; // Se till att sökvägen till din modell är korrekt
import '../providers/theme_provider.dart';


class ExerciseListItem extends ConsumerWidget {
  // Denna widget tar emot ett Exercise-objekt för att veta vad den ska visa.
  final Exercise exercise;
  final VoidCallback onMenuPressed;
  final bool isReordering; // Ny parameter



  const ExerciseListItem({
    Key? key,
    required this.exercise,
    required this.onMenuPressed,
    this.isReordering = false, // Standardvärde är false

  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    
    return Card(
      color: theme.card, // Mörkgrå färg som i din design
      margin: const EdgeInsets.symmetric(vertical: 8.0), // Lite utrymme mellan varje item
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0), // Rundade hörn
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
        title: Text(
          exercise.name,
          style: TextStyle(
            color: theme.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${exercise.sets} sets total',
              style: TextStyle(
                color: theme.textSecondary,
              ),
            ),
            if (exercise.warmUpSets > 0)
              Row(
                children: [
                  Icon(Icons.local_fire_department, 
                       color: theme.accent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${exercise.warmUpSets} warm-up + ${exercise.workingSets} working',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else
              Text(
                '${exercise.workingSets} working sets',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: isReordering
            ? Icon(Icons.drag_handle, color: theme.text)
            : IconButton(
                icon: Icon(Icons.more_vert, color: theme.text),
                onPressed: onMenuPressed,
              ),
      ),
    );
  }
}