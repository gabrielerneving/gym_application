import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_provider.dart'; 

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

        // Skapa/uppdatera controllers baserat på om användaren redigerat fältet
        // Logik: Bara redigerade fält ska ha text i controller
        // Icke-redigerade fält ska vara tomma så placeholder (hint) visas
        // Om värdet är 0 eller null och inte redierat, visa som tomt (inte som "0")
        final isWeightEdited = providerEdited.contains(weightKey);
        final isRepsEdited = providerEdited.contains(repsKey);
        final isNotesEdited = providerEdited.contains(notesKey);

        String weightText = '';
        String repsText = '';
        String notesText = '';

        if (isWeightEdited && set.weight > 0) {
          weightText = set.weight.toString();
        }
        if (isRepsEdited && set.reps > 0) {
          repsText = set.reps.toString();
        }
        if (isNotesEdited && set.notes != null && set.notes!.isNotEmpty) {
          notesText = set.notes!;
        }

        _controllers[weightKey]?.dispose();
        _controllers[repsKey]?.dispose();
        _controllers[notesKey]?.dispose();
        _controllers[weightKey] = TextEditingController(text: weightText);
        _controllers[repsKey] = TextEditingController(text: repsText);
        _controllers[notesKey] = TextEditingController(text: notesText);
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

  void _showWorkoutOptionsDialog() {
    final session = ref.read(workoutProvider).session;
    if (session == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Edit Program', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Modify exercises and sets', style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context);
                  _editCurrentProgram();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text('Workout Info', style: TextStyle(color: Colors.white)),
                subtitle: const Text('View program details', style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context); 
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _editCurrentProgram() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Edit Active Workout?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Editing the program will pause your current workout. Your progress will be saved.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implementera fullständig edit-funktionalitet för active workout
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit during active workout - Coming soon!'),
                  backgroundColor: Color(0xFFDC2626),
                ),
              );
            },
            child: const Text('Continue', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ÄNDRING 3: Läs det aktuella statet från providern.
    // .watch() gör att skärmen automatiskt byggs om när statet ändras.
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
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }

    // Hantera tillbaka-knappen utan dialog
    return WillPopScope(
      onWillPop: () async {
        // Timer fortsätter att köra
        return true; 
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
        backgroundColor: Colors.black,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                  onPressed: () => _showWorkoutOptionsDialog(),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.black87],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          session.programTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(
                            formatDuration(activeWorkoutState.elapsedSeconds),
                            style: const TextStyle(
                              color: Colors.white,
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
                                    color: const Color(0xFFDC2626), 
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + exerciseIndex),
                                      style: const TextStyle(
                                        color: Color.fromARGB(255, 255, 255, 255),
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                                warmUpSets: warmUpSets,
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
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: session.completedExercises.length,
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
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Finish Workout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
}

class SwipeableSetRowNew extends ConsumerStatefulWidget {
  final dynamic set;
  final int setIndex;
  final int exerciseIndex;
  final int warmUpSets; 
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
    required this.warmUpSets,
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
      _swipeOffset = _swipeOffset.clamp(-60.0, 60.0); 
    });
  }

  void _handlePanEnd(DragEndDetails details) {
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
        // haptic feedback
        HapticFeedback.lightImpact();
        
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
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        final offset = _animationController.isAnimating ? _offsetAnimation.value : _swipeOffset;
        
        // Clean swipe animation
        final swipeProgress = (offset.abs() / 60.0).clamp(0.0, 1.0);
        final hasPlaceholders = (widget.set.weight > 0 || widget.set.reps > 0 || 
                               (widget.set.notes != null && widget.set.notes!.isNotEmpty));
        
        // Minimal design färger
        Color containerColor = Colors.grey.shade900;
        if (hasPlaceholders && swipeProgress > 0.1) {
          containerColor = Color.lerp(
            Colors.grey.shade900,
            Colors.white.withOpacity(0.05),
            swipeProgress * 0.5,
          )!;
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
                  color: Colors.grey.shade800.withOpacity(0.6),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  // Set nummer - different design for warm-up vs working sets
                  Container(
                    width: 24, 
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.set.isWarmUp 
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: widget.set.isWarmUp 
                        ? Border.all(color: Colors.orange.withOpacity(0.4), width: 1)
                        : null,
                    ),
                    child: Center(
                      child: widget.set.isWarmUp
                        ? Icon(
                            Icons.local_fire_department,
                            color: Colors.orange,
                            size: 14,
                          )
                        : Text(
                            '${widget.setIndex - widget.warmUpSets + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Set type label
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.set.isWarmUp ? 'Warm-up' : 'Working',
                          style: TextStyle(
                            color: widget.set.isWarmUp ? Colors.orange : Colors.grey.shade400,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          widget.set.isWarmUp 
                            ? 'Set ${widget.setIndex + 1}'
                            : 'Set ${widget.setIndex - widget.warmUpSets + 1}',
                          style: TextStyle(
                            color: widget.set.isWarmUp ? Colors.orange.shade300 : Colors.grey.shade500,
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Weight input - clean design
                  Expanded(
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
                  const SizedBox(width: 12),
                  
                  // Notes input
                  Expanded(
                    flex: 2,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController? controller,
    required Color textColor,
    required String hintText,
    required TextInputType keyboardType,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
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
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white, width: 1),
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