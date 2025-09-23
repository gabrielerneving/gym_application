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
  // Lokal cache används inte längre som sanning; vi läser från provider-state
  final Set<String> _editedFields = {}; // kept only for transient UI but source of truth is provider
  String? _currentSessionId; // to prevent redundant reinitialization

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Anropas när dependencies ändras (t.ex. när provider state uppdateras)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }
  
  // Metod för att skapa alla controllers när skärmen startar
  void _initializeControllers() {
    final session = ref.read(workoutProvider).session;
    if (session == null) return;

    // Only reinitialize when session id changes
    if (_currentSessionId == session.id && _controllers.isNotEmpty) {
      // Still update edited fields cache
      final providerEdited = ref.read(workoutProvider).editedFields;
      _editedFields
        ..clear()
        ..addAll(providerEdited);
      return;
    }
    _currentSessionId = session.id;

    // Synka editedFields med provider
    final providerEdited = ref.read(workoutProvider).editedFields;
    _editedFields
      ..clear()
      ..addAll(providerEdited);

    for (int exIndex = 0; exIndex < session.completedExercises.length; exIndex++) {
      final exercise = session.completedExercises[exIndex];
      for (int setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
        final set = exercise.sets[setIndex];
        
        // Skapa unika nycklar för varje fält
        final weightKey = 'w_${exIndex}_$setIndex';
        final repsKey = 'r_${exIndex}_$setIndex';
        final notesKey = 'n_${exIndex}_$setIndex';

        // Skapa/uppdatera controllers baserat på om användaren redigerat fältet
        // Logik: Bara redigerade fält ska ha text i controller
        // Icke-redigerade fält ska vara tomma så placeholder (hint) visas
        final isWeightEdited = providerEdited.contains(weightKey);
        final isRepsEdited = providerEdited.contains(repsKey);
        final isNotesEdited = providerEdited.contains(notesKey);

        final weightText = isWeightEdited ? set.weight.toString() : '';
        final repsText = isRepsEdited ? set.reps.toString() : '';
        final notesText = isNotesEdited ? (set.notes ?? '') : '';

        _controllers[weightKey]?.dispose();
        _controllers[repsKey]?.dispose();
        _controllers[notesKey]?.dispose();
        _controllers[weightKey] = TextEditingController(text: weightText);
        _controllers[repsKey] = TextEditingController(text: repsText);
        _controllers[notesKey] = TextEditingController(text: notesText);
      }
    }
    
    // Tvinga en rebuild efter att controllers initialiserats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
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

  @override
  // ÄNDRING 2: build-metoden tar nu bara BuildContext eftersom ref är tillgängligt direkt
  Widget build(BuildContext context) {
    // ÄNDRING 3: Läs det aktuella statet från providern.
    // .watch() gör att skärmen automatiskt byggs om när statet ändras.
    final activeWorkoutState = ref.watch(workoutProvider);
    final session = activeWorkoutState.session;

    // Säkerställ att controllers är initierade när vi har en session
    if (session != null && _controllers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeControllers();
      });
    }

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

    // Hantera tillbaka-knappen utan dialog
    return WillPopScope(
      onWillPop: () async {
        // Pausa passet automatiskt när användaren lämnar
        ref.read(workoutProvider.notifier).pauseWorkout();
        return true; // Tillåt navigering direkt
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

                          // Bestäm textfärgen. Om fältet finns i editedFields (från provider), använd vit. Annars, grå.
                          final providerState = ref.watch(workoutProvider);
                          final edited = providerState.editedFields;
                          final weightColor = edited.contains(weightKey) ? Colors.white : Colors.grey.shade400;
                          final repsColor = edited.contains(repsKey) ? Colors.white : Colors.grey.shade400;
                          final notesColor = edited.contains(notesKey) ? Colors.white : Colors.grey.shade400;
                          
                          return SwipeableSetRowNew(
                            set: set,
                            setIndex: setIndex,
                            exerciseIndex: exerciseIndex,
                            weightKey: weightKey,
                            repsKey: repsKey,
                            notesKey: notesKey,
                            controllers: _controllers,
                            editedFields: ref.watch(workoutProvider).editedFields,
                            onFieldEdited: (fieldKey) {
                              ref.read(workoutProvider.notifier).markFieldEdited(fieldKey);
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
      duration: const Duration(milliseconds: 400), // Längre för Material 3 Expressive
      vsync: this,
    );
    _offsetAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic, // Material 3 Expressive curve
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
      _swipeOffset = _swipeOffset.clamp(-60.0, 60.0); // Större range för mjukare känsla
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    // Material 3 Expressive: Lägre hastighetströskel och mjukare detection
    final horizontalVelocity = details.velocity.pixelsPerSecond.dx.abs();
    final verticalVelocity = details.velocity.pixelsPerSecond.dy.abs();
    final isHorizontalSwipe = horizontalVelocity > verticalVelocity;
    final hasEnoughVelocity = horizontalVelocity > 200; // Lägre tröskel
    final hasEnoughDistance = _swipeOffset.abs() > 20; // Alternativ: tillräcklig distans
    
    if (isHorizontalSwipe && (hasEnoughVelocity || hasEnoughDistance)) {
      // Läs placeholders från provider (förra passets värden)
      final ph = ref.read(workoutProvider).placeholders;
      final wKey = 'w_${widget.exerciseIndex}_${widget.setIndex}';
      final rKey = 'r_${widget.exerciseIndex}_${widget.setIndex}';
      final nKey = 'n_${widget.exerciseIndex}_${widget.setIndex}';

      final hasPlaceholders = ((ph[wKey] is num && (ph[wKey] as num) > 0) ||
          (ph[rKey] is num && (ph[rKey] as num) > 0) ||
          (ph[nKey] is String && (ph[nKey] as String).isNotEmpty));

      if (hasPlaceholders) {
        // Provide haptic feedback
        HapticFeedback.lightImpact();
        
        // Fill in the controllers and mark as edited
        double? w;
        int? r;
        String? n;
        if (ph[wKey] is num && (ph[wKey] as num) > 0) {
          w = (ph[wKey] as num).toDouble();
          widget.controllers[widget.weightKey]?.text = w.toString();
          widget.onFieldEdited(widget.weightKey);
        }
        if (ph[rKey] is num && (ph[rKey] as num) > 0) {
          r = (ph[rKey] as num).toInt();
          widget.controllers[widget.repsKey]?.text = r.toString();
          widget.onFieldEdited(widget.repsKey);
        }
        if (ph[nKey] is String && (ph[nKey] as String).isNotEmpty) {
          n = ph[nKey] as String;
          widget.controllers[widget.notesKey]?.text = n;
          widget.onFieldEdited(widget.notesKey);
        }

        // Update session data med dessa värden
        ref.read(workoutProvider.notifier).updateSetData(
          widget.exerciseIndex,
          widget.setIndex,
          weight: w,
          reps: r,
          notes: n,
        );
      }
    }
    
    // Material 3 Expressive: Mjuk animation tillbaka med easing curve
    _offsetAnimation = Tween<double>(
      begin: _swipeOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic, // Material 3 Expressive curve
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
    // Debug: kolla vad controller faktiskt innehåller
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        final offset = _animationController.isAnimating ? _offsetAnimation.value : _swipeOffset;
        
        // Material 3 Expressive: Mjuk färgförändring baserat på swipe progress
        final swipeProgress = (offset.abs() / 60.0).clamp(0.0, 1.0);
        final hasPlaceholders = (widget.set.weight > 0 || widget.set.reps > 0 || 
                               (widget.set.notes != null && widget.set.notes!.isNotEmpty));
        
        // Färg som ändras baserat på swipe och om placeholders finns
        Color containerColor = Colors.black;
        Color borderColor = Colors.grey.shade800;
        
        if (hasPlaceholders && swipeProgress > 0.1) {
          // Material 3 Expressive: Gradvis färgförändring
          containerColor = Color.lerp(
            Colors.black,
            const Color(0xFFDC2626).withOpacity(0.1),
            swipeProgress * 0.8,
          )!;
          borderColor = Color.lerp(
            Colors.grey.shade800,
            const Color(0xFFDC2626).withOpacity(0.6),
            swipeProgress,
          )!;
        }
        
        return Transform.translate(
          offset: Offset(offset, 0),
          child: GestureDetector(
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor,
                  width: 1 + (swipeProgress * 1), // Tjockare border vid swipe
                ),
                // Material 3 Expressive: Mjuk shadow vid swipe
                boxShadow: swipeProgress > 0.1 ? [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(swipeProgress * 0.3),
                    blurRadius: 8 * swipeProgress,
                    spreadRadius: 1 * swipeProgress,
                  ),
                ] : null,
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
                            hintText: (() {
                              final ph = ref.watch(workoutProvider).placeholders;
                              final v = ph['w_${widget.exerciseIndex}_${widget.setIndex}'];
                              if (v is num && v > 0) return v.toString();
                              return null;
                            })(),
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
                            if (value.isEmpty) {
                              ref.read(workoutProvider.notifier).unmarkFieldEdited(widget.weightKey);
                            } else {
                              widget.onFieldEdited(widget.weightKey);
                            }
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
                            hintText: (() {
                              final ph = ref.watch(workoutProvider).placeholders;
                              final v = ph['r_${widget.exerciseIndex}_${widget.setIndex}'];
                              if (v is num && v > 0) return v.toString();
                              return null;
                            })(),
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
                            if (value.isEmpty) {
                              ref.read(workoutProvider.notifier).unmarkFieldEdited(widget.repsKey);
                            } else {
                              widget.onFieldEdited(widget.repsKey);
                            }
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
                            hintText: (() {
                              final ph = ref.watch(workoutProvider).placeholders;
                              final v = ph['n_${widget.exerciseIndex}_${widget.setIndex}'];
                              if (v is String && v.isNotEmpty) return v;
                              return null;
                            })(),
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
                            if (value.isEmpty) {
                              ref.read(workoutProvider.notifier).unmarkFieldEdited(widget.notesKey);
                            } else {
                              widget.onFieldEdited(widget.notesKey);
                            }
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