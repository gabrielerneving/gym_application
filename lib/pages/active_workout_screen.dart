import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../widgets/gradient_button.dart';
import '../pages/choose_category_screen.dart';
import '../models/master_exercise_model.dart';
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  // En Map för att hålla alla controllers
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _editedFields = {}; 
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

    if (_currentSessionId == session.id && _controllers.isNotEmpty) {
      final providerEdited = ref.read(workoutProvider).editedFields;
      _editedFields
        ..clear()
        ..addAll(providerEdited);
      return;
    }
    _currentSessionId = session.id;

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
        final rirKey = 'rir_${exIndex}_$setIndex';

        // Skapa/uppdatera controllers baserat på om användaren redigerat fältet
        // Logik: Bara redigerade fält ska ha text i controller
        // Icke-redigerade fält ska vara tomma så placeholder (hint) visas
        // Om värdet är 0 eller null och inte redierat, visa som tomt (inte som "0")
        final isWeightEdited = providerEdited.contains(weightKey);
        final isRepsEdited = providerEdited.contains(repsKey);
        final isNotesEdited = providerEdited.contains(notesKey);
        final isRirEdited = providerEdited.contains(rirKey);

        String weightText = '';
        String repsText = '';
        String notesText = '';
        String rirText = '';

        if (isWeightEdited && set.weight > 0) {
          weightText = set.weight.toString();
        }
        if (isRepsEdited && set.reps > 0) {
          repsText = set.reps.toString();
        }
        if (isNotesEdited && set.notes != null && set.notes!.isNotEmpty) {
          notesText = set.notes!;
        }
        if (isRirEdited && set.rir != null && set.rir! > 0) {
          rirText = set.rir.toString();
        }

        _controllers[weightKey]?.dispose();
        _controllers[repsKey]?.dispose();
        _controllers[notesKey]?.dispose();
        _controllers[rirKey]?.dispose();
        _controllers[weightKey] = TextEditingController(text: weightText);
        _controllers[repsKey] = TextEditingController(text: repsText);
        _controllers[notesKey] = TextEditingController(text: notesText);
        _controllers[rirKey] = TextEditingController(text: rirText);
      }
    }
    
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



  @override
  Widget build(BuildContext context) {
    // ÄNDRING 3: Läs det aktuella statet från providern.
    // .watch() gör att skärmen automatiskt byggs om när statet ändras.
    final theme = ref.watch(themeProvider);
    final activeWorkoutState = ref.watch(workoutProvider);
    final session = activeWorkoutState.session;

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

    // Om inget pass är igång (t.ex. om användaren navigerar hit via en länk av misstag eller på något sätt),
    // visa ett felmeddelande.
    if (session == null || !activeWorkoutState.isRunning) {
      return const Scaffold(
        body: Center(child: Text('No active workout found.')),
      );
    }

    // formatering för timern
    String formatDuration(int totalSeconds) {
      final duration = Duration(seconds: totalSeconds);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }

    // Hantera tillbaka-knappen utan dialog
    return WillPopScope(
      onWillPop: () async {
        // Spara workout state innan användaren lämnar skärmen
        ref.read(workoutProvider.notifier).saveCurrentState();
        // Timer fortsätter att köra
        return true; 
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
        backgroundColor: theme.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: theme.background,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: theme.text, size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: theme.text),
                  onSelected: (value) {
                    if (value == 'save_as_workout') {
                      _showSaveAsWorkoutDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'save_as_workout',
                      child: Row(
                        children: [
                          Icon(Icons.save, color: theme.text, size: 20),
                          const SizedBox(width: 12),
                          Text('Save as Workout', style: TextStyle(color: theme.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [theme.background, theme.background.withOpacity(0.87)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          session.programTitle,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.textSecondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.textSecondary.withOpacity(0.2)),
                          ),
                          child: Text(
                            formatDuration(activeWorkoutState.elapsedSeconds),
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Övningar lista
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, exerciseIndex) {
                    final exercise = session.completedExercises[exerciseIndex];
                    final warmUpSets = exercise.sets.where((set) => set.isWarmUp).length;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Övningsnamn
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: theme.primary, 
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + exerciseIndex),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    exercise.name,
                                    style: TextStyle(
                                      color: theme.text,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                // Exercise menu (three dots)
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, color: theme.text, size: 20),
                                  onSelected: (value) {
                                    if (value == 'add_set') {
                                      _addSet(exerciseIndex);
                                    } else if (value == 'remove_set') {
                                      // Remove last set if more than 1
                                      if (exercise.sets.length > 1) {
                                        _removeSet(exerciseIndex, exercise.sets.length - 1);
                                      }
                                    } else if (value == 'remove_exercise') {
                                      _removeExercise(exerciseIndex);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'add_set',
                                      child: Row(
                                        children: [
                                          Icon(Icons.add_circle_outline, color: theme.primary, size: 20),
                                          const SizedBox(width: 12),
                                          Text('Add Set', style: TextStyle(color: theme.text)),
                                        ],
                                      ),
                                    ),
                                    if (exercise.sets.length > 1)
                                      PopupMenuItem(
                                        value: 'remove_set',
                                        child: Row(
                                          children: [
                                            Icon(Icons.remove_circle_outline, color: Colors.orange.withOpacity(0.7), size: 20),
                                            const SizedBox(width: 12),
                                            Text('Remove Last Set', style: TextStyle(color: theme.text)),
                                          ],
                                        ),
                                      ),
                                    if (session.completedExercises.length > 1)
                                      PopupMenuItem(
                                        value: 'remove_exercise',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 20),
                                            const SizedBox(width: 12),
                                            Text('Remove Exercise', style: TextStyle(color: theme.text)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Sets lista med clean design
                          Column(
                            children: exercise.sets.asMap().entries.map((entry) {
                              final setIndex = entry.key;
                              final set = entry.value;
                              
                              // Hämta de unika nycklarna för detta set
                              final weightKey = 'w_${exerciseIndex}_$setIndex';
                              final repsKey = 'r_${exerciseIndex}_$setIndex';
                              final notesKey = 'n_${exerciseIndex}_$setIndex';
                              final rirKey = 'rir_${exerciseIndex}_$setIndex';

                              // Bestäm textfärgen. Om fältet finns i editedFields (från provider), använd vit. Annars, grå.
                              final providerState = ref.watch(workoutProvider);
                              final edited = providerState.editedFields;
                              final weightColor = edited.contains(weightKey) ? theme.text : theme.textSecondary;
                              final repsColor = edited.contains(repsKey) ? theme.text : theme.textSecondary;
                              final notesColor = edited.contains(notesKey) ? theme.text : theme.textSecondary;
                              final rirColor = edited.contains(rirKey) ? theme.text : theme.textSecondary;
                              
                              return SwipeableSetRowNew(
                                set: set,
                                setIndex: setIndex,
                                exerciseIndex: exerciseIndex,
                                warmUpSets: warmUpSets,
                                weightKey: weightKey,
                                repsKey: repsKey,
                                notesKey: notesKey,
                                rirKey: rirKey,
                                controllers: _controllers,
                                editedFields: ref.watch(workoutProvider).editedFields,
                                onFieldEdited: (fieldKey) {
                                  ref.read(workoutProvider.notifier).markFieldEdited(fieldKey);
                                  setState(() {
                                    _editedFields.add(fieldKey);
                                  });
                                },
                                onDeleteSet: exercise.sets.length > 1 
                                  ? () => _removeSet(exerciseIndex, setIndex)
                                  : null,
                                weightColor: weightColor,
                                repsColor: repsColor,
                                notesColor: notesColor,
                                rirColor: rirColor,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: session.completedExercises.length,
                ),
              ),
            ),

            // Add Exercise Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _showAddExerciseDialog,
                  icon: Icon(Icons.add_circle_outline, color: theme.primary),
                  label: Text(
                    'Add Exercise',
                    style: TextStyle(color: theme.primary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: theme.primary, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),

            // Clean finish workout knapp, alltid längst ner
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.all(20),
                    child: GradientButton(
                      text: 'Finish Workout',
                      onPressed: () async {
                        HapticFeedback.mediumImpact(); // Haptic när workout avslutas
                        await ref.read(workoutProvider.notifier).finishWorkout();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      width: double.infinity,
                      height: 56,
                      borderRadius: 28,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
  
  void _addSet(int exerciseIndex) {
    ref.read(workoutProvider.notifier).addSet(exerciseIndex);
  }
  
  void _removeSet(int exerciseIndex, int setIndex) {
    ref.read(workoutProvider.notifier).removeSet(exerciseIndex, setIndex);
  }

  void _removeExercise(int exerciseIndex) {
    ref.read(workoutProvider.notifier).removeExercise(exerciseIndex);
  }

  Future<void> _showAddExerciseDialog() async {
    // Navigate to ChooseCategoryScreen to select from master exercises
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChooseCategoryScreen()),
    );

    // If user selected a master exercise, show dialog to configure sets
    if (result != null && result is MasterExercise && mounted) {
      _showConfigureSetsDialog(result.name);
    }
  }

  Future<void> _showConfigureSetsDialog(String exerciseName) async {
    final TextEditingController setsController = TextEditingController(text: '3');
    final TextEditingController warmUpController = TextEditingController(text: '0');
    final theme = ref.read(themeProvider);
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.card,
          title: Text('Configure Sets', style: TextStyle(color: theme.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                exerciseName,
                style: TextStyle(color: theme.text, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: setsController,
                style: TextStyle(color: theme.text),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Working Sets',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.textSecondary)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.primary)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: warmUpController,
                style: TextStyle(color: theme.text),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Warm-up Sets',
                  labelStyle: TextStyle(color: theme.textSecondary),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.textSecondary)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.primary)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final sets = int.tryParse(setsController.text) ?? 3;
                final warmUp = int.tryParse(warmUpController.text) ?? 0;
                
                ref.read(workoutProvider.notifier).addExercise(
                  exerciseName,
                  sets: sets,
                  warmUpSets: warmUp,
                );
                Navigator.of(context).pop();
              },
              child: Text('Add', style: TextStyle(color: theme.primary)),
            ),
          ],
        );
      },
    );
  }
  
  void _showSaveAsWorkoutDialog() async {
    final theme = ref.read(themeProvider);
    final TextEditingController nameController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.card,
        title: Text(
          'Save as Workout',
          style: TextStyle(color: theme.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: theme.text),
              decoration: InputDecoration(
                labelText: 'Workout Name',
                labelStyle: TextStyle(color: theme.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.textSecondary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a workout name')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              // Save the workout template
              await ref.read(workoutProvider.notifier).saveActiveWorkoutAsTemplate(name, overwrite: false);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Workout saved as \"$name\"')),
                );
              }
            },
            child: Text('Save', style: TextStyle(color: theme.primary)),
          ),
        ],
      ),
    );
  }
}

class SwipeableSetRowNew extends ConsumerStatefulWidget {
  final dynamic set;
  final int setIndex;
  final int exerciseIndex;
  final int warmUpSets; 
  final String weightKey;
  final String repsKey;
  final String notesKey;
  final String rirKey;
  final Map<String, TextEditingController> controllers;
  final Set<String> editedFields;
  final Function(String) onFieldEdited;
  final VoidCallback? onDeleteSet;
  final Color weightColor;
  final Color repsColor;
  final Color notesColor;
  final Color rirColor;

  const SwipeableSetRowNew({
    Key? key,
    required this.set,
    required this.setIndex,
    required this.exerciseIndex,
    required this.warmUpSets,
    required this.weightKey,
    required this.repsKey,
    required this.notesKey,
    required this.rirKey,
    required this.controllers,
    required this.editedFields,
    required this.onFieldEdited,
    this.onDeleteSet,
    required this.weightColor,
    required this.repsColor,
    required this.notesColor,
    required this.rirColor,
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
      duration: const Duration(milliseconds: 400), 
      vsync: this,
    );
    _offsetAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
      _swipeOffset = _swipeOffset.clamp(-80.0, 80.0); // Öka range för bättre feedback
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    final horizontalVelocity = details.velocity.pixelsPerSecond.dx.abs();
    final verticalVelocity = details.velocity.pixelsPerSecond.dy.abs();
    final isHorizontalSwipe = horizontalVelocity > verticalVelocity;
    final hasEnoughVelocity = horizontalVelocity > 100; // Mycket lägre tröskel för lättare trigga
    final hasEnoughDistance = _swipeOffset.abs() > 15; // Lägre distans krävs
    
    if (isHorizontalSwipe && (hasEnoughVelocity || hasEnoughDistance)) {
      // Läs placeholders från provider (förra passets värden)
      final ph = ref.read(workoutProvider).placeholders;
      final wKey = 'w_${widget.exerciseIndex}_${widget.setIndex}';
      final rKey = 'r_${widget.exerciseIndex}_${widget.setIndex}';
      final nKey = 'n_${widget.exerciseIndex}_${widget.setIndex}';
      final rirKey = 'rir_${widget.exerciseIndex}_${widget.setIndex}';

      final hasPlaceholders = ((ph[wKey] is num && (ph[wKey] as num) > 0) ||
          (ph[rKey] is num && (ph[rKey] as num) > 0) ||
          (ph[nKey] is String && (ph[nKey] as String).isNotEmpty) ||
          (ph[rirKey] is num && (ph[rirKey] as num) > 0));

      if (hasPlaceholders) {
        // Enhanced haptic feedback
        HapticFeedback.mediumImpact(); // Starkare feedback för bättre känsla
        
        double? w;
        int? r;
        String? n;
        int? rir;
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
        if (ph[rirKey] is num && (ph[rirKey] as num) > 0) {
          rir = (ph[rirKey] as num).toInt();
          widget.controllers[widget.rirKey]?.text = rir.toString();
          widget.onFieldEdited(widget.rirKey);
        }

        // Update session data med dessa värden
        ref.read(workoutProvider.notifier).updateSetData(
          widget.exerciseIndex,
          widget.setIndex,
          weight: w,
          reps: r,
          notes: n,
          rir: rir,
        );
      }
    }
    
    _offsetAnimation = Tween<double>(
      begin: _swipeOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic, 
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
    final theme = ref.watch(themeProvider);
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        final offset = _animationController.isAnimating ? _offsetAnimation.value : _swipeOffset;
        
        // Enhanced swipe animation med bättre feedback
        final swipeProgress = (offset.abs() / 80.0).clamp(0.0, 1.0); // Anpassad till ny range
        final ph = ref.watch(workoutProvider).placeholders;
        final wKey = 'w_${widget.exerciseIndex}_${widget.setIndex}';
        final rKey = 'r_${widget.exerciseIndex}_${widget.setIndex}';
        final nKey = 'n_${widget.exerciseIndex}_${widget.setIndex}';
        final rirKey = 'rir_${widget.exerciseIndex}_${widget.setIndex}';
        
        final hasPlaceholders = ((ph[wKey] is num && (ph[wKey] as num) > 0) ||
            (ph[rKey] is num && (ph[rKey] as num) > 0) ||
            (ph[nKey] is String && (ph[nKey] as String).isNotEmpty) ||
            (ph[rirKey] is num && (ph[rirKey] as num) > 0));
        
        // Enhanced visual feedback
        Color containerColor = theme.card;
        Color? borderColor;
        double borderWidth = 0.5;
        
        if (hasPlaceholders && swipeProgress > 0.05) {
          // Gradvis färgändring för bättre feedback
          containerColor = Color.lerp(
            theme.card,
            theme.primary.withOpacity(0.1),
            swipeProgress * 0.8,
          )!;
          
          // Border effect när swipe är tillräckligt stark
          if (swipeProgress > 0.3) {
            borderColor = theme.primary.withOpacity(swipeProgress);
            borderWidth = 1.0 + (swipeProgress * 1.0);
          }
        }
        
        return Transform.translate(
          offset: Offset(offset, 0),
          child: GestureDetector(
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor ?? theme.textSecondary.withOpacity(0.2),
                  width: borderWidth,
                ),
                // Subtle glow effect när det finns data att fylla i
                boxShadow: hasPlaceholders && swipeProgress > 0.1 ? [
                  BoxShadow(
                    color: theme.primary.withOpacity(0.1 * swipeProgress),
                    blurRadius: 8.0 * swipeProgress,
                    spreadRadius: 2.0 * swipeProgress,
                  ),
                ] : null,
              ),
              child: Column(
                children: [
                  // Header row with set info and progression
                  Row(
                    children: [
                      // Set nummer - different design for warm-up vs working sets
                      Container(
                        width: 28, 
                        height: 28,
                        decoration: BoxDecoration(
                          color: widget.set.isWarmUp 
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: widget.set.isWarmUp 
                            ? Border.all(color: Colors.orange.withOpacity(0.4), width: 1)
                            : null,
                        ),
                        child: Center(
                          child: widget.set.isWarmUp
                            ? Icon(
                                Icons.local_fire_department,
                                color: Colors.orange,
                                size: 16,
                              )
                            : Text(
                                '${widget.setIndex - widget.warmUpSets + 1}',
                                style: TextStyle(
                                  color: theme.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Set type label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.set.isWarmUp ? 'Warm-up' : 'Working Set',
                              style: TextStyle(
                                color: widget.set.isWarmUp ? Colors.orange : theme.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              widget.set.isWarmUp 
                                ? 'Set ${widget.setIndex + 1}'
                                : 'Set ${widget.setIndex - widget.warmUpSets + 1}',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Progression indicator (conditionally shown)
                      if (_buildProgressionIndicator(ref) != null) 
                        _buildProgressionIndicator(ref)!,
                      
                      // Delete set button
                      if (widget.onDeleteSet != null)
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: Colors.red.withOpacity(0.7), size: 20),
                          onPressed: widget.onDeleteSet,
                          tooltip: 'Remove set',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Input fields row
                  Row(
                    children: [
                      // Weight input - clean design
                      Expanded(
                        flex: 3,
                        child: _buildInputField(
                          label: 'kg',
                          controller: widget.controllers[widget.weightKey],
                          textColor: widget.weightColor,
                          hintText: (() {
                            final ph = ref.watch(workoutProvider).placeholders;
                            final v = ph['w_${widget.exerciseIndex}_${widget.setIndex}'];
                            if (v is num && v > 0) return v.toString();
                            return '';
                          })(),
                          keyboardType: TextInputType.number,
                          theme: theme,
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
                      ),
                      const SizedBox(width: 12),
                      
                      // Reps input
                      Expanded(
                        flex: 3,
                        child: _buildInputField(
                          label: 'reps',
                          controller: widget.controllers[widget.repsKey],
                          textColor: widget.repsColor,
                          hintText: (() {
                            final ph = ref.watch(workoutProvider).placeholders;
                            final v = ph['r_${widget.exerciseIndex}_${widget.setIndex}'];
                            if (v is num && v > 0) return v.toString();
                            return '';
                          })(),
                          keyboardType: TextInputType.number,
                          theme: theme,
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
                      ),
                      
                      // RIR input (conditionally shown)
                      if (ref.watch(workoutSettingsProvider).showRIR) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildInputField(
                            label: 'RIR',
                            controller: widget.controllers[widget.rirKey],
                            textColor: widget.rirColor,
                            hintText: (() {
                              final ph = ref.watch(workoutProvider).placeholders;
                              final v = ph['rir_${widget.exerciseIndex}_${widget.setIndex}'];
                              if (v is num && v > 0) return v.toString();
                              return '';
                            })(),
                            keyboardType: TextInputType.number,
                            theme: theme,
                            onChanged: (value) {
                              if (value.isEmpty) {
                                ref.read(workoutProvider.notifier).unmarkFieldEdited(widget.rirKey);
                              } else {
                                widget.onFieldEdited(widget.rirKey);
                              }
                              final rir = int.tryParse(value) ?? 0;
                              ref.read(workoutProvider.notifier).updateSetData(
                                widget.exerciseIndex, widget.setIndex, rir: rir
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      
                      // Notes input
                      Expanded(
                        flex: 4,
                        child: _buildInputField(
                          label: 'notes',
                          controller: widget.controllers[widget.notesKey],
                          textColor: widget.notesColor,
                          hintText: (() {
                            final ph = ref.watch(workoutProvider).placeholders;
                            final v = ph['n_${widget.exerciseIndex}_${widget.setIndex}'];
                            if (v is String && v.isNotEmpty) return v;
                            return '';
                          })(),
                          keyboardType: TextInputType.text,
                          theme: theme,
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildProgressionIndicator(WidgetRef ref) {
    // Only show if progression is enabled and not warm-up set
    if (!ref.watch(workoutSettingsProvider).showProgression || widget.set.isWarmUp) {
      return null;
    }

    final theme = ref.watch(themeProvider);
    final placeholders = ref.watch(workoutProvider).placeholders;
    final previousWeight = placeholders['w_${widget.exerciseIndex}_${widget.setIndex}'];
    final previousReps = placeholders['r_${widget.exerciseIndex}_${widget.setIndex}'];
    
    // Only show progression if we have previous data
    if (previousWeight == null || previousReps == null) {
      return null;
    }
    
    final currentWeight = widget.set.weight;
    final currentReps = widget.set.reps;
    
    // Don't show if current set is empty (not yet filled in)
    if (currentWeight == 0 || currentReps == 0) return null;
    
    // Use saved progressions or calculate dynamically
    int? repProgression = widget.set.progression;
    double? weightProgression = widget.set.weightProgression;
    
    // Calculate rep progression if not saved (backwards compatibility)
    if (repProgression == null && currentWeight == previousWeight) {
      final repsDifference = currentReps - (previousReps as int);
      if (repsDifference != 0) {
        repProgression = repsDifference;
      }
    }
    
    // Calculate weight progression if not saved (backwards compatibility)
    if (weightProgression == null && currentReps >= (previousReps as int)) {
      final weightDifference = currentWeight - (previousWeight as num).toDouble();
      if (weightDifference != 0) {
        weightProgression = weightDifference;
      }
    }
    
    // Build indicators
    final List<Widget> indicators = [];
    
    // Rep progression indicator (green/red)
    if (repProgression != null && repProgression != 0) {
      final isPositive = repProgression > 0;
      final color = isPositive ? Colors.green : Colors.red;
      final icon = isPositive ? Icons.trending_up : Icons.trending_down;
      
      indicators.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}$repProgression reps',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Weight progression indicator (primary color/orange based on theme)
    if (weightProgression != null && weightProgression != 0) {
      final isPositive = weightProgression > 0;
      // Use primary color for positive, orange for negative to differentiate from rep progression
      final color = isPositive ? theme.primary : Colors.orange;
      final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
      
      indicators.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${weightProgression.toStringAsFixed(1)} kg',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Return null if no indicators
    if (indicators.isEmpty) return null;
    
    // Return single indicator or row of indicators
    if (indicators.length == 1) {
      return indicators.first;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicators[0],
        const SizedBox(width: 6),
        indicators[1],
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController? controller,
    required Color textColor,
    required String hintText,
    required TextInputType keyboardType,
    required Function(String) onChanged,
    required theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText.isEmpty ? null : hintText,
            hintStyle: TextStyle(
              color: theme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            filled: true,
            fillColor: theme.card.withOpacity(0.8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.textSecondary.withOpacity(0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: theme.primary,
                width: 2,
              ),
            ),
          ),
          keyboardType: keyboardType,
          textAlign: label == 'notes' ? TextAlign.left : TextAlign.center,
          // Gör notes-fältet expanderande vertikalt
          maxLines: label == 'notes' ? null : 1,
          minLines: label == 'notes' ? 1 : 1,
          expands: false,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

