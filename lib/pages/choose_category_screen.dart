import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import 'create_exercise_screen.dart'; 
import 'exercise_list_screen.dart'; 

class ChooseCategoryScreen extends ConsumerWidget {
  const ChooseCategoryScreen({Key? key}) : super(key: key);

  // Hårdkodad lista med kategorier för tillfället, ska kanske ändras??.
  final List<String> categories = const [
    'Shoulders',
    'Quads',
    'Hamstrings',
    'Glutes',
    'Calf',
    'Biceps',
    'Triceps',
    'Chest',
    'Back',
    'Abs',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: Text('Choose exercise', style: TextStyle(color: theme.text)),
        backgroundColor: theme.background,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.primary, size: 30),
            onPressed: () {
              // Navigera till skärmen för att skapa en ny övning 
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CreateExerciseScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
         return Card(
          color: theme.card,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), 
            side: BorderSide(
              color: theme.textSecondary.withOpacity(0.3), 
              width: 1,          
            ),
          ),
          child: ListTile(
            title: Text(
              category,
              style: TextStyle(color: theme.text),
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: theme.text, size: 16),
            onTap: () async {
              final selectedExercise = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ExerciseListScreen(category: category),
                ),
              );

              if (selectedExercise != null) {
                Navigator.of(context).pop(selectedExercise);
              }
            },
          ),
        );

        },
      ),
    );
  }
}