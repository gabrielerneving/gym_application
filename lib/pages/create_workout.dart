import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart'; 
import '../models/exercise_model.dart';
import '../providers/theme_provider.dart';
import '../models/workout_model.dart';
import '../services/database_service.dart';
import '../widgets/exercise_list_item.dart';
import '../widgets/gradient_button.dart';
import '../widgets/gradient_text.dart';
import 'choose_category_screen.dart'; 
import '../models/master_exercise_model.dart'; 




class CreateWorkoutScreen extends ConsumerStatefulWidget {
  final Function(int)? onWorkoutSaved;
   final WorkoutProgram? workoutToEdit;
  const CreateWorkoutScreen({
    Key? key,
    this.onWorkoutSaved,
    this.workoutToEdit,
  }) : super(key: key);

  @override
  _CreateWorkoutScreenState createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends ConsumerState<CreateWorkoutScreen> {
  final _workoutNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isReordering = false; 


  
  List<Exercise> _exercises = [];

  void initState() {
    super.initState();

    // Kontrollera om vi är i "edit mode"
    if (widget.workoutToEdit != null) {
      // Fyll i controllern med det befintliga namnet
      _workoutNameController.text = widget.workoutToEdit!.title;
      // Fyll i listan med de befintliga övningarna
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
  final theme = ref.read(themeProvider);
  showModalBottomSheet(
    context: context,
    backgroundColor: theme.card, 
    builder: (BuildContext bc) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: ListTile(
                  leading: Icon(Icons.edit, color: theme.text),
                  title: Text('Edit', style: TextStyle(color: theme.text)),
                  onTap: () {
                    Navigator.of(context).pop(); // Stäng menyn först
                    _showEditSetsDialog(exercise); // Anropa sedan dialogen för att ändra sets
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: ListTile(
                  leading: Icon(Icons.delete, color: theme.text),
                  title: Text('Remove', style: TextStyle(color: theme.text)),
                  onTap: () {
                    Navigator.of(context).pop(); 
                    setState(() {
                      _exercises.removeAt(index); // Ta bort övningen från listan
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: ListTile(
                leading: Icon(Icons.reorder, color: theme.text),
                title: Text('Change order', style: TextStyle(color: theme.text)),
                onTap: () {
                  Navigator.of(context).pop(); 
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
  final theme = ref.watch(themeProvider);
  final workingSetsController = TextEditingController(text: exercise.workingSets.toString());
  final warmUpSetsController = TextEditingController(text: exercise.warmUpSets.toString());

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Edit sets for ${exercise.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: workingSetsController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Working Sets',
                hintText: 'Sets that count in statistics',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: warmUpSetsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Warm-up Sets',
                hintText: 'Sets for warming up (optional)',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${(int.tryParse(workingSetsController.text) ?? 0) + (int.tryParse(warmUpSetsController.text) ?? 0)} sets',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Save', style: TextStyle(color: theme.text)),
            onPressed: () {
              setState(() {
                final workingSets = int.tryParse(workingSetsController.text) ?? 0;
                final warmUpSets = int.tryParse(warmUpSetsController.text) ?? 0;
                
                exercise.workingSets = workingSets;
                exercise.warmUpSets = warmUpSets;
                exercise.sets = workingSets + warmUpSets; // Uppdatera total
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}


Future<void> _navigateAndAddExercise() async {
  // Navigera till Skärm A (ChooseCategoryScreen) och VÄNTA på ett resultat.
  // Resultatet kommer att vara ett MasterExercise-objekt om användaren väljer en,
  // annars blir det null om de bara backar ut.
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ChooseCategoryScreen()),
  );


  // Kontrollera om vi faktiskt fick tillbaka ett resultat (dvs. inte null)
  if (result != null && result is MasterExercise) {
    // VIKTIGT: Vi fick tillbaka ett MasterExercise, men vår lista i denna
    // skärm är en lista av "vanliga" Exercise-objekt (som också har "sets").
    // Vi måste konvertera den ena till den andra. Vi sätter "sets" till 1 som standard.
    final newExercise = Exercise(
      id: const Uuid().v4(), // Skapa ett HELT NYTT unikt ID för denna instans!
      name: result.name,
      sets: 1, // Sätt ett standardvärde för total sets
      workingSets: 1, // Default: 3 working sets
      warmUpSets: 0, // Default: 0 warm-up sets
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
      // CREATE-LÄGE 
      final newProgram = WorkoutProgram(
        id: const Uuid().v4(),
        title: _workoutNameController.text.trim(),
        exercises: _exercises,
      );
      await DatabaseService(uid: uid).saveWorkoutProgram(newProgram);
    }

      // 5. Stäng tangentbordet först
      FocusManager.instance.primaryFocus?.unfocus();
      
      // 6. Ge feedback och navigera tillbaka
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved successfully!')),
        );

      _workoutNameController.clear();
      setState(() {
        _exercises.clear();
      });

        // Stäng tangentbordet först
        FocusManager.instance.primaryFocus?.unfocus();
        
        // Gå till Home tab (index 0) istället för att bara poppa
        if (widget.onWorkoutSaved != null) {
          widget.onWorkoutSaved!(0); // 0 = Home tab
        } else {
          Navigator.of(context).pop();
        } 
      }

    } catch (e) { 

    
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
  final theme = ref.watch(themeProvider);
  return GestureDetector(
    onTap: () {
      FocusScope.of(context).unfocus();
    },
    child: Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.background, 
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 50, 16, 60), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GradientText(
                  text: widget.workoutToEdit == null ? 'Create Workout' : 'Edit Workout',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                  currentThemeIndex: ref.watch(themeIndexProvider),
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
                    style: ElevatedButton.styleFrom(backgroundColor: theme.success),
                    child: Text('Done', style: TextStyle(color: theme.text)),
                  )
                else
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveWorkout,
                    style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Text('Save', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _workoutNameController,
              focusNode: _focusNode,
              style: TextStyle(color: theme.text),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: theme.text),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), 
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), 
                  borderSide: BorderSide(color: theme.textSecondary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), 
                  borderSide: BorderSide(color: theme.primary),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: SizedBox(
                width: 330, 
                child: Divider(
                  color: theme.primary,
                  thickness: 1,
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView(
                // Denna funktion är centrala delen i ReorderableListView.
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
                child: GradientButton(
                  text: 'Add exercise',
                  onPressed: () {
                    _navigateAndAddExercise();
                  },
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 55,
                  borderRadius: 20,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 40),
          ],
        ),
      ),
    ),
  );
}
}