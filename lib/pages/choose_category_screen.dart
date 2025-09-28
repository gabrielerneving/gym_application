import 'package:flutter/material.dart';
import 'create_exercise_screen.dart'; 
import 'exercise_list_screen.dart'; 

class ChooseCategoryScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose exercise'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.red, size: 30),
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
          color: Colors.grey.shade900,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), 
            side: const BorderSide(
              color: Color(0xFF4D4D4D), 
              width: 1,          
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