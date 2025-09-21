import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; 
import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../services/database_service.dart';
import '../widgets/exercise_list_item.dart';
import 'choose_category_screen.dart'; // Importera den nya skärmen
import '../models/master_exercise_model.dart'; // Importera MasterExercise-modellen




class CreateWorkoutScreen extends StatefulWidget {
  final Function(int)? onWorkoutSaved;
   final WorkoutProgram? workoutToEdit;
  const CreateWorkoutScreen({
    Key? key,
    this.onWorkoutSaved,
    // NYTT: Lägg till den i konstruktorn
    this.workoutToEdit,
  }) : super(key: key);

  @override
  _CreateWorkoutScreenState createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final _workoutNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isReordering = false; // Håller koll på om vi kan ändra ordning


  
  List<Exercise> _exercises = [];

  void initState() {
    super.initState();
    
    // NYTT: Kontrollera om vi är i "edit mode"
    if (widget.workoutToEdit != null) {
      // Fyll i controllern med det befintliga namnet
      _workoutNameController.text = widget.workoutToEdit!.title;
      // Fyll i listan med de befintliga övningarna
      // VIKTIGT: Vi skapar en ny lista för att undvika att ändra i originalobjektet av misstag
      _exercises = List.from(widget.workoutToEdit!.exercises);
    }
    
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // METOD 1: Visar själva menyn
void _showExerciseOptions(BuildContext context, Exercise exercise, int index) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey.shade900, // Mörk bakgrundsfärg som i din design
    builder: (BuildContext bc) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text('Ändra', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(context).pop(); // Stäng menyn först
                    _showEditSetsDialog(exercise); // Anropa sedan dialogen för att ändra sets
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: ListTile(
                  leading: const Icon(Icons.delete, color: Colors.white),
                  title: const Text('Ta bort', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(context).pop(); // Stäng menyn
                    setState(() {
                      _exercises.removeAt(index); // Ta bort övningen från listan
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: ListTile(
                leading: const Icon(Icons.reorder, color: Colors.white),
                title: const Text('Ändra ordning', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop(); // Stäng menyn
                  // Växla till omordningsläge
                  setState(() {
                    _isReordering = true;
                  });
                },
                          ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// METOD 2: Visar en dialog för att ändra antal sets
Future<void> _showEditSetsDialog(Exercise exercise) async {
  final setsController = TextEditingController(text: exercise.sets.toString());

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Edit sets for ${exercise.name}'),
        content: TextField(
          controller: setsController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Number of Sets'),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () {
              setState(() {
                // Uppdatera antalet sets på den befintliga övningen
                exercise.sets = int.tryParse(setsController.text) ?? exercise.sets;
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}


// NY METOD FÖR ATT HANTERA DET NYA FLÖDET
Future<void> _navigateAndAddExercise() async {
  // Navigera till Skärm A (ChooseCategoryScreen) och VÄNTA på ett resultat.
  // Resultatet kommer att vara ett MasterExercise-objekt om användaren väljer en,
  // annars blir det null om de bara backar ut.
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ChooseCategoryScreen()),
  );

    print('👉 RESULT RECEIVED: $result');


  // Kontrollera om vi faktiskt fick tillbaka ett resultat (dvs. inte null)
  if (result != null && result is MasterExercise) {
    // VIKTIGT: Vi fick tillbaka ett MasterExercise, men vår lista i denna
    // skärm är en lista av "vanliga" Exercise-objekt (som också har "sets").
    // Vi måste konvertera den ena till den andra. Vi sätter "sets" till 1 som standard.
    final newExercise = Exercise(
      id: const Uuid().v4(), // Skapa ett HELT NYTT unikt ID för denna instans!
      name: result.name,
      sets: 1, // Sätt ett standardvärde för sets
    );

    // Lägg till den nya övningen i listan och rita om UI:t
    setState(() {
      _exercises.add(newExercise);
    });
  }
}

  // Metod som anropas när "Save" trycks
  Future<void> _saveWorkout() async {
    // 1. Validera att fälten inte är tomma
    if (_workoutNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the workout.')),
      );
      return;
    }
    if (_exercises.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise.')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // 2. Hämta den inloggade användarens unika ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Detta bör inte hända om AuthGate fungerar, men det är en bra säkerhetskoll
        throw Exception("No user logged in!");
      }
      final uid = user.uid;
      
      if (widget.workoutToEdit != null) {
      // UPDATE-LÄGE
      final updatedProgram = WorkoutProgram(
        id: widget.workoutToEdit!.id, // Använd det befintliga ID:t!
        title: _workoutNameController.text.trim(),
        exercises: _exercises,
      );
      await DatabaseService(uid: uid).updateWorkoutProgram(updatedProgram);
    } else {
      // CREATE-LÄGE (din befintliga kod)
      final newProgram = WorkoutProgram(
        id: const Uuid().v4(),
        title: _workoutNameController.text.trim(),
        exercises: _exercises,
      );
      await DatabaseService(uid: uid).saveWorkoutProgram(newProgram);
    }

      // 5. Ge feedback och navigera tillbaka
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved successfully!')),
        );

      _workoutNameController.clear();
      setState(() {
        _exercises.clear();
      });

        // Gå till Home tab (index 0) istället för att bara poppa
        if (widget.onWorkoutSaved != null) {
          widget.onWorkoutSaved!(0); // 0 = Home tab
        } else {
          Navigator.of(context).pop();
        } 
      }

    } catch (e, s) { // Fånga även "stack trace"
    // DENNA DEL ÄR NY OCH VIKTIG
    print('🚨 AN ERROR OCCURRED AFTER SAVING!');
    print('Error object: $e');
    print('Stack trace: $s');
    
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during post-save operation: $e')),
      );
    }
  } finally {
     if(mounted) {
       setState(() { _isLoading = false; });
     }
  }
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
        padding: const EdgeInsets.fromLTRB(16, 50, 16, 60), // Ökat top padding för bättre spacing
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // NYTT: Byt text baserat på läge
                  widget.workoutToEdit == null ? 'Create' : 'Edit Workout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Om vi är i omordningsläge, visa en "Done"-knapp.
                // Annars, visa den vanliga "Save"-knappen.
                if (_isReordering)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isReordering = false; // Gå tillbaka till normalläge
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
                  )
                else
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveWorkout,
                    style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFDC2626)),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _workoutNameController,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: const TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // default rundade hörn
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // rundade hörn även här
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // rundade hörn när fältet är aktivt
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Center(
              child: SizedBox(
                width: 330, // här styr du längden
                child: Divider(
                  color: Color(0xFFDC2626),
                  thickness: 1,
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView(
                // Denna funktion är HJÄRTAT i ReorderableListView.
                // Den anropas när användaren har dragit ett objekt och släppt det på en ny plats.
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    // Justeringen här är viktig: om man flyttar ett objekt neråt i listan,
                    // förskjuts indexen på ett annat sätt än om man flyttar det uppåt.
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    // Ta bort objektet från sin gamla plats...
                    final Exercise item = _exercises.removeAt(oldIndex);
                    // ...och sätt in det på sin nya plats.
                    _exercises.insert(newIndex, item);
                  });
                },
                // Bygger varje objekt i listan.
                children: _exercises.map((exercise) {
                  return Container(
                    // VIKTIGT: Varje barn i en ReorderableListView måste ha en unik Key.
                    key: Key(exercise.id),
                    child: ExerciseListItem(
                      exercise: exercise,
                      isReordering: _isReordering, // Skicka med det aktuella läget
                      onMenuPressed: () {
                        // Hitta index för den specifika övningen för att kunna ta bort den
                        final index = _exercises.indexOf(exercise);
                        _showExerciseOptions(context, exercise, index);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Visibility(
              visible: !_focusNode.hasFocus,
              child: Center(
                child: ElevatedButton(
                  onPressed: () {
                    _navigateAndAddExercise();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFDC2626),
                    minimumSize: Size(MediaQuery.of(context).size.width * 0.8, 55), // 80% av skärmbredden
                  ),
                  child: const Text(
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