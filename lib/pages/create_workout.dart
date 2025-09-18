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
  final FocusNode _focusNode = FocusNode();
  bool _isKeyboardVisible = false;
  
  final List<Exercise> _exercises = [
    // Exempeldata, denna lista kommer du att kunna ändra
    Exercise(name: 'Incline press', sets: 2, id: 'ex1'),
    Exercise(name: 'Incline press', sets: 2, id: 'ex2'),
    Exercise(name: 'Incline press', sets: 2, id: 'ex3'),
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isKeyboardVisible = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Ta bort focus när man klickar utanför textfältet
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFDC2626)),
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
              focusNode: _focusNode,
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
            const SizedBox(height: 30),

            Center(
              child: SizedBox(
                width: 330, // här styr du längden
                child: Divider(
                  color: Color(0xFFDC2626),
                  thickness: 1,
                ),
              ),
            ),

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
            Visibility(
              visible: !_focusNode.hasFocus,
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Logik för att lägga till en ny övning
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFDC2626),
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
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 40), // Dynamisk höjd
          ],
        ),
      ),
    ),
    );
  }
}