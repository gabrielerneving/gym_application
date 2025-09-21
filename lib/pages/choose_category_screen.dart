import 'package:flutter/material.dart';
import 'create_exercise_screen.dart'; // Skärm C
import 'exercise_list_screen.dart'; // Skärm B

class ChooseCategoryScreen extends StatelessWidget {
  const ChooseCategoryScreen({Key? key}) : super(key: key);

  // Hårdkodad lista med kategorier. Kan senare hämtas från databasen om man vill.
  final List<String> categories = const [
    'Shoulders',
    'Legs',
    'Biceps',
    'Triceps',
    'Chest',
    'Back',
    'Abs',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose exercise'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.red, size: 30),
            onPressed: () {
              // Navigera till skärmen för att skapa en ny övning (Skärm C)
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
          color: Colors.grey.shade900,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // rundade hörn
            side: const BorderSide(
              color: Color(0xFF4D4D4D), // färgen på ramen
              width: 1,          // tjockleken på ramen
            ),
          ),
          child: ListTile(
            title: Text(
              category,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
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