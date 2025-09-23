import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_provider.dart'; // Importera vår nya provider

// ÄNDRING 1: Byt från ConsumerWidget till ConsumerStatefulWidget
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  // En Map för att hålla alla våra controllers
  final Map<String, TextEditingController> _controllers = {};
  // En Set för att hålla reda på vilka fält som har redigerats
  final Set<String> _editedFields = {};
  // Håll reda på nuvarande sessionens ID för att detektera när en ny session startar
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }

  @override
  void didUpdateWidget(ActiveWorkoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize controllers when widget updates (e.g., new workout started)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }
  
  // Metod för att skapa alla controllers när skärmen startar
  void _initializeControllers() {
    final session = ref.read(workoutProvider).session;
    if (session == null) return;

    // Kontrollera om detta är en ny session
    if (_currentSessionId != session.id) {
      _currentSessionId = session.id;
      
      // Rensa tidigare controllers och editedFields för ny session
      _controllers.clear();
      _editedFields.clear();

      for (int exIndex = 0; exIndex < session.completedExercises.length; exIndex++) {
        for (int setIndex = 0; setIndex < session.completedExercises[exIndex].sets.length; setIndex++) {
          // Skapa unika nycklar för varje fält
          final weightKey = 'w_${exIndex}_$setIndex';
          final repsKey = 'r_${exIndex}_$setIndex';
          final notesKey = 'n_${exIndex}_$setIndex';

          _controllers[weightKey] = TextEditingController(text: ''); // Start tomt för placeholders
          _controllers[repsKey] = TextEditingController(text: ''); // Start tomt för placeholders  
          _controllers[notesKey] = TextEditingController(text: ''); // Start tomt för placeholders
        }
      }
    }
  }

  @override
  void dispose() {
    // Mycket viktigt att rensa upp alla controllers för att undvika minnesläckor!
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Vi behöver inte längre ta emot ett program, eftersom vi läser det från providern.

  // En hjälpmetod för att visa bekräftelsedialogen
  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave workout?'),
        content: const Text('Your progress will be saved. You can resume later from the home screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  // ÄNDRING 2: build-metoden tar nu bara BuildContext eftersom ref är tillgängligt direkt
  Widget build(BuildContext context) {
    // ÄNDRING 3: Läs det aktuella statet från providern.
    // .watch() gör att skärmen automatiskt byggs om när statet ändras.
    final activeWorkoutState = ref.watch(workoutProvider);
    final session = activeWorkoutState.session;

    // Återinitialisera controllers om session ändras (ny workout startar)
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeControllers();
      });
    }

    // Om inget pass är igång (t.ex. om användaren navigerar hit via en länk av misstag),
    // visa ett felmeddelande.
    if (session == null || !activeWorkoutState.isRunning) {
      return const Scaffold(
        body: Center(child: Text('No active workout found.')),
      );
    }

    // Snygg formatering för timern
    String formatDuration(int totalSeconds) {
      final duration = Duration(seconds: totalSeconds);
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }

    // ÄNDRING 4: Använd WillPopScope för att hantera "tillbaka"-knappen
    return WillPopScope(
      onWillPop: () async {
        final shouldLeave = await _showExitConfirmationDialog(context);
        if (shouldLeave) {
          // Anropa notifiern för att pausa passet
          ref.read(workoutProvider.notifier).pauseWorkout();
        }
        return shouldLeave; // Returnera true för att tillåta navigering
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.programTitle),
          centerTitle: true,
          backgroundColor: Colors.black,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            // ÄNDRING 5: Läs tiden från providern
            child: Text(
              "Time: ${formatDuration(activeWorkoutState.elapsedSeconds)}",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // Lista med alla övningar (tog bort timer header)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: session.completedExercises.length,
                itemBuilder: (context, exerciseIndex) {
                  final exercise = session.completedExercises[exerciseIndex];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 0, 0),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Övningsnamn med bokstav
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + exerciseIndex), // A, B, C, etc.
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                exercise.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Sets
                        ...exercise.sets.asMap().entries.map((entry) {
                          final setIndex = entry.key;
                          final set = entry.value;
                          
                          // Hämta de unika nycklarna för detta set
                          final weightKey = 'w_${exerciseIndex}_$setIndex';
                          final repsKey = 'r_${exerciseIndex}_$setIndex';
                          final notesKey = 'n_${exerciseIndex}_$setIndex';

                          // Bestäm textfärgen. Om fältet finns i _editedFields, använd vit. Annars, grå.
                          final weightColor = _editedFields.contains(weightKey) ? Colors.white : Colors.grey.shade400;
                          final repsColor = _editedFields.contains(repsKey) ? Colors.white : Colors.grey.shade400;
                          final notesColor = _editedFields.contains(notesKey) ? Colors.white : Colors.grey.shade400;
                          
                          return SwipeableSetRowNew(
                            set: set,
                            setIndex: setIndex,
                            exerciseIndex: exerciseIndex,
                            weightKey: weightKey,
                            repsKey: repsKey,
                            notesKey: notesKey,
                            controllers: _controllers,
                            editedFields: _editedFields,
                            onFieldEdited: (fieldKey) {
                              setState(() {
                                _editedFields.add(fieldKey);
                              });
                            },
                            weightColor: weightColor,
                            repsColor: repsColor,
                            notesColor: notesColor,
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Finish workout button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(workoutProvider.notifier).finishWorkout();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Finish Workout',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SwipeableSetRowNew extends ConsumerStatefulWidget {
  final dynamic set;
  final int setIndex;
  final int exerciseIndex;
  final String weightKey;
  final String repsKey;
  final String notesKey;
  final Map<String, TextEditingController> controllers;
  final Set<String> editedFields;
  final Function(String) onFieldEdited;
  final Color weightColor;
  final Color repsColor;
  final Color notesColor;

  const SwipeableSetRowNew({
    Key? key,
    required this.set,
    required this.setIndex,
    required this.exerciseIndex,
    required this.weightKey,
    required this.repsKey,
    required this.notesKey,
    required this.controllers,
    required this.editedFields,
    required this.onFieldEdited,
    required this.weightColor,
    required this.repsColor,
    required this.notesColor,
  }) : super(key: key);

  @override
  ConsumerState<SwipeableSetRowNew> createState() => _SwipeableSetRowNewState();
}

class _SwipeableSetRowNewState extends ConsumerState<SwipeableSetRowNew>
    with TickerProviderStateMixin {
  double _swipeOffset = 0.0;
  late AnimationController _animationController;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _swipeOffset += details.delta.dx;
      _swipeOffset = _swipeOffset.clamp(-30.0, 30.0);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    // Check if it was a horizontal swipe with sufficient velocity
    if (details.velocity.pixelsPerSecond.dx.abs() > 500 &&
        details.velocity.pixelsPerSecond.dx.abs() > details.velocity.pixelsPerSecond.dy.abs()) {
      
      // Only fill if there are placeholder values to use
      bool hasPlaceholders = (widget.set.weight > 0 || widget.set.reps > 0 || 
                            (widget.set.notes != null && widget.set.notes!.isNotEmpty));
      
      if (hasPlaceholders) {
        // Provide haptic feedback
        HapticFeedback.lightImpact();
        
        // Fill in the controllers and mark as edited
        if (widget.set.weight > 0) {
          widget.controllers[widget.weightKey]?.text = widget.set.weight.toString();
          widget.onFieldEdited(widget.weightKey);
        }
        if (widget.set.reps > 0) {
          widget.controllers[widget.repsKey]?.text = widget.set.reps.toString();
          widget.onFieldEdited(widget.repsKey);
        }
        if (widget.set.notes != null && widget.set.notes!.isNotEmpty) {
          widget.controllers[widget.notesKey]?.text = widget.set.notes!;
          widget.onFieldEdited(widget.notesKey);
        }
        
        // Update session data
        ref.read(workoutProvider.notifier).updateSetData(
          widget.exerciseIndex,
          widget.setIndex,
          weight: widget.set.weight > 0 ? widget.set.weight : null,
          reps: widget.set.reps > 0 ? widget.set.reps : null,
          notes: (widget.set.notes != null && widget.set.notes!.isNotEmpty) ? widget.set.notes : null,
        );
        
        // Show brief visual feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Set ${widget.setIndex + 1} filled with previous values!'),
                ],
              ),
              duration: const Duration(milliseconds: 1200),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
    
    // Reset swipe offset with animation
    _offsetAnimation = Tween<double>(
      begin: _swipeOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _swipeOffset = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        final offset = _animationController.isAnimating ? _offsetAnimation.value : _swipeOffset;
        
        return Transform.translate(
          offset: Offset(offset, 0),
          child: GestureDetector(
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade800,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Set nummer
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.setIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Weight input
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weight',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        TextFormField(
                          controller: widget.controllers[widget.weightKey],
                          style: TextStyle(color: widget.weightColor),
                          decoration: InputDecoration(
                            hintText: widget.set.weight > 0 ? widget.set.weight.toString() : null,
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade600),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade600),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFDC2626)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            widget.onFieldEdited(widget.weightKey);
                            final weight = double.tryParse(value) ?? 0.0;
                            ref.read(workoutProvider.notifier).updateSetData(
                              widget.exerciseIndex, widget.setIndex, weight: weight, reps: widget.set.reps
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Reps input
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reps',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        TextFormField(
                          controller: widget.controllers[widget.repsKey],
                          style: TextStyle(color: widget.repsColor),
                          decoration: InputDecoration(
                            hintText: widget.set.reps > 0 ? widget.set.reps.toString() : null,
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade600),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade600),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFDC2626)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            widget.onFieldEdited(widget.repsKey);
                            final reps = int.tryParse(value) ?? 0;
                            ref.read(workoutProvider.notifier).updateSetData(
                              widget.exerciseIndex, widget.setIndex, weight: widget.set.weight, reps: reps
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Notes input
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        TextFormField(
                          controller: widget.controllers[widget.notesKey],
                          style: TextStyle(color: widget.notesColor),
                          decoration: InputDecoration(
                            hintText: (widget.set.notes != null && widget.set.notes!.isNotEmpty) ? widget.set.notes : null,
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade600),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade600),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFDC2626)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          textAlign: TextAlign.left,
                          onChanged: (value) {
                            widget.onFieldEdited(widget.notesKey);
                            ref.read(workoutProvider.notifier).updateSetData(
                              widget.exerciseIndex,
                              widget.setIndex,
                              notes: value,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}