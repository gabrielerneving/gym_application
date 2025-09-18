import 'package:flutter/material.dart';
import '../models/exercise_model.dart'; // Importera dina modeller
import '../widgets/exercise_list_item.dart'; // Importera din widget för listan

class CreateWorkoutScreen extends StatefulWidget {
  const CreateWorkoutScreen({Key? key}) : super(key: key);

  @override
  _CreateWorkoutScreenState createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _workoutNameController = TextEditingController();
  final List<Exercise> _exercises = [
    // Exempeldata, denna lista kommer du att kunna ändra
    Exercise(name: 'Incline press', sets: 2, id: 'ex1'),
    Exercise(name: 'Incline press', sets: 2, id: 'ex2'),
    Exercise(name: 'Incline press', sets: 2, id: 'ex3'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sätter bakgrundsfärgen
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Spara-logik här
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _workoutNameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // default rundade hörn
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // rundade hörn även här
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // rundade hörn när fältet är aktivt
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
            ),

            const SizedBox(height: 20),
             Expanded(
              child: ListView.builder(
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  // Ersätt den gamla Card-logiken med din nya widget!
                  return ExerciseListItem(exercise: _exercises[index]);
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Logik för att lägga till en ny övning
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: Size(MediaQuery.of(context).size.width * 0.8, 55), // 80% av skärmbredden
                ),
                child: Text(
                      'Add exercise',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 40), // Extra utrymme för navigation bar
          ],
        ),
      ),
    );
  }
}