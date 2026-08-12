import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/master_exercise_model.dart';
import '../models/workout_session_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../widgets/ui/ui.dart';
import 'choose_category_screen.dart';

/// ---------------------------------------------------------------------------
/// The live workout screen.
///
/// Designed for one-handed use at a rack: a frosted header that always shows
/// the elapsed time and the finish action, exercise cards holding a compact set
/// table, and set rows with tap targets big enough to hit while out of breath.
///
/// All state lives in [workoutProvider]; this screen only renders it and owns
/// the text controllers for the inputs.
/// ---------------------------------------------------------------------------
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  /// One [TextEditingController] per input field, keyed exactly like the
  /// provider's placeholder/edited-field keys (`w_<exercise>_<setIndex>` …).
  final Map<String, TextEditingController> _controllers = {};

  /// Fingerprint of the session *structure* (id + exercises + set counts).
  /// Controllers are only rebuilt when this changes, so typing never resets a
  /// field and a rebuild storm can never recreate controllers under the user.
  String? _structureSignature;

  /// True between "finish confirmed" and leaving the screen — keeps the page
  /// from flashing the empty state while the session is being saved.
  bool _finishing = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _syncControllers(ref.read(workoutProvider));
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  static String _signatureOf(WorkoutSession? session) {
    if (session == null) return '';
    final buffer = StringBuffer(session.id);
    for (final exercise in session.completedExercises) {
      buffer
        ..write('|')
        ..write(exercise.name)
        ..write(':')
        ..write(exercise.sets.length);
    }
    return buffer.toString();
  }

  /// Rebuilds the controller map so it matches the session exactly.
  ///
  /// Only fields the user has actually edited get text — everything else stays
  /// empty so the hint (last session's value) shows through, which is the same
  /// contract the provider's `editedFields` set describes.
  void _syncControllers(ActiveWorkoutState state) {
    final signature = _signatureOf(state.session);
    if (signature == _structureSignature) return;
    _structureSignature = signature;

    // Retire the previous controllers only once this frame has been painted:
    // the fields still holding them are not rebuilt until the end of it, and a
    // disposed controller that is still attached to a live TextField would
    // throw if the platform delivered one last keystroke.
    final retired = _controllers.values.toList(growable: false);
    _controllers.clear();
    if (retired.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in retired) {
          controller.dispose();
        }
      });
    }

    final session = state.session;
    if (session == null) return;

    final edited = state.editedFields;
    for (final exercise in session.completedExercises) {
      for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
        final set = exercise.sets[setIndex];
        final keys = _SetKeys(exercise.name, setIndex);

        _controllers[keys.weight] = TextEditingController(
          text: edited.contains(keys.weight) && set.weight > 0
              ? AppFormat.weight(set.weight)
              : '',
        );
        _controllers[keys.reps] = TextEditingController(
          text: edited.contains(keys.reps) && set.reps > 0
              ? set.reps.toString()
              : '',
        );
        _controllers[keys.notes] = TextEditingController(
          text: edited.contains(keys.notes) &&
                  set.notes != null &&
                  set.notes!.isNotEmpty
              ? set.notes!
              : '',
        );
        _controllers[keys.rir] = TextEditingController(
          text: edited.contains(keys.rir) && set.rir != null && set.rir! > 0
              ? set.rir.toString()
              : '',
        );
      }
    }
  }

  void _onWorkoutStateChanged(
    ActiveWorkoutState? previous,
    ActiveWorkoutState next,
  ) {
    if (_signatureOf(next.session) == _structureSignature) return;
    setState(() => _syncControllers(next));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    // Structural changes (add/remove set or exercise, session finished) arrive
    // here first, before the rebuild that renders them.
    ref.listen<ActiveWorkoutState>(workoutProvider, _onWorkoutStateChanged);

    if (_finishing) {
      return const AppPage(
        child: Center(child: LoadingState(message: 'Saving your workout…')),
      );
    }

    final session = ref.watch(workoutProvider.select((s) => s.session));
    final isRunning = ref.watch(workoutProvider.select((s) => s.isRunning));
    final staleSession =
        ref.watch(workoutProvider.select((s) => s.staleSession));

    if (session == null || !isRunning) {
      return AppPage(
        child: SafeArea(
          child: _InactiveWorkoutView(
            stale: staleSession,
            onResume: () =>
                ref.read(workoutProvider.notifier).resumeStaleWorkout(),
            onDiscard: _discardStaleWorkout,
          ),
        ),
      );
    }

    final exercises = session.completedExercises;
    final summary = _WorkoutSummary.of(session);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Leaving the screen never stops the workout — just flush the state.
        ref.read(workoutProvider.notifier).saveCurrentState();
      },
      child: AppPage(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  extent: topInset + _ActiveWorkoutHeader.totalHeight,
                  child: _ActiveWorkoutHeader(
                    topInset: topInset,
                    title: session.programTitle,
                    exerciseCount: exercises.length,
                    summary: summary,
                    onBack: () => Navigator.of(context).maybePop(),
                    onMenu: _showWorkoutMenu,
                    onFinish: _finishWorkout,
                  ),
                ),
              ),
              if (exercises.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.huge),
                    child: EmptyState(
                      icon: Icons.fitness_center_rounded,
                      title: 'No exercises yet',
                      message:
                          'This session is empty. Add an exercise to start logging sets.',
                      actionLabel: 'Add exercise',
                      onAction: _addExercise,
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final exercise = exercises[index];
                      return Padding(
                        key: ValueKey('exercise_$index'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: FadeSlideIn(
                          index: index,
                          child: _ExerciseCard(
                            exerciseIndex: index,
                            exercise: exercise,
                            controllers: _controllers,
                            canRemoveExercise: exercises.length > 1,
                            onAddSet: () => _addSet(index),
                            onRemoveLastSet: () =>
                                _removeSet(index, exercise.sets.length - 1),
                            onRemoveSet: (setIndex) =>
                                _removeSet(index, setIndex),
                            onRemoveExercise: () => _removeExercise(index),
                          ),
                        ),
                      );
                    },
                    childCount: exercises.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.xs,
                    AppSpacing.screenH,
                    AppSpacing.xxxl + bottomInset,
                  ),
                  child: Column(
                    children: [
                      AppButton.outline(
                        label: 'Add exercise',
                        icon: Icons.add_rounded,
                        expand: true,
                        onPressed: _addExercise,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _SessionSummaryCard(summary: summary),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton.secondary(
                        label: 'Finish workout',
                        icon: Icons.flag_rounded,
                        size: AppButtonSize.large,
                        expand: true,
                        onPressed: _finishWorkout,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your timer keeps running if you leave this screen.',
                        textAlign: TextAlign.center,
                        style: AppType.caption(t),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Set / exercise mutations
  // ---------------------------------------------------------------------------

  void _addSet(int exerciseIndex) {
    HapticFeedback.selectionClick();
    ref.read(workoutProvider.notifier).addSet(exerciseIndex);
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    if (setIndex < 0) return;
    HapticFeedback.selectionClick();
    ref.read(workoutProvider.notifier).removeSet(exerciseIndex, setIndex);
  }

  Future<void> _removeExercise(int exerciseIndex) async {
    final session = ref.read(workoutProvider).session;
    if (session == null || exerciseIndex >= session.completedExercises.length) {
      return;
    }
    final name = session.completedExercises[exerciseIndex].name;

    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Remove $name?',
      message: 'Every set you logged for this exercise is removed from the '
          'session. This cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    ref.read(workoutProvider.notifier).removeExercise(exerciseIndex);
    if (!mounted) return;
    AppSnack.show(context, ref, '$name removed');
  }

  Future<void> _addExercise() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChooseCategoryScreen()),
    );
    if (result is! MasterExercise || !mounted) return;

    final MasterExercise picked = result;
    final String exerciseName = picked.name;

    final config = await AppSheet.show<_ExerciseConfig>(
      context: context,
      ref: ref,
      title: exerciseName,
      subtitle: 'How many sets are you doing?',
      builder: (context) => _ConfigureSetsSheet(exerciseName: exerciseName),
    );
    if (config == null || !mounted) return;

    ref.read(workoutProvider.notifier).addExercise(
          exerciseName,
          sets: config.workingSets,
          warmUpSets: config.warmUpSets,
        );
    if (!mounted) return;
    AppSnack.show(context, ref, '$exerciseName added');
  }

  void _discardStaleWorkout() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Discard unfinished workout?',
      message: 'The saved session will be deleted and nothing is added to your '
          'history.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    ref.read(workoutProvider.notifier).discardStaleWorkout();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  // ---------------------------------------------------------------------------
  // Templates
  // ---------------------------------------------------------------------------

  void _showWorkoutMenu() {
    final session = ref.read(workoutProvider).session;
    if (session == null) return;

    AppSheet.actions(
      context: context,
      ref: ref,
      title: 'Workout options',
      actions: [
        SheetAction(
          icon: Icons.add_rounded,
          label: 'Add exercise',
          description: 'Pick one from your library',
          onTap: _addExercise,
        ),
        SheetAction(
          icon: Icons.save_rounded,
          label: 'Save & update template',
          description: 'Overwrite "${session.programTitle}" with this layout',
          onTap: _updateOriginalTemplate,
        ),
        SheetAction(
          icon: Icons.bookmark_add_rounded,
          label: 'Save as new workout',
          description: 'Create a new template from these exercises',
          onTap: _showSaveAsWorkoutSheet,
        ),
      ],
    );
  }

  Future<void> _showSaveAsWorkoutSheet() async {
    final name = await AppSheet.show<String>(
      context: context,
      ref: ref,
      title: 'Save as workout',
      subtitle: 'Store today\'s exercises and set counts as a new template.',
      builder: (context) => const _WorkoutNameSheet(),
    );
    if (name == null || !mounted) return;

    await ref
        .read(workoutProvider.notifier)
        .saveActiveWorkoutAsTemplate(name, overwrite: false);
    if (!mounted) return;
    AppSnack.show(context, ref, 'Workout saved as "$name"');
  }

  Future<void> _updateOriginalTemplate() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Update template',
      message: 'The original workout template is replaced with the exercises '
          'and sets you have right now. Continue?',
      confirmLabel: 'Update',
      icon: Icons.save_rounded,
    );
    if (!confirmed || !mounted) return;

    await ref.read(workoutProvider.notifier).updateOriginalTemplate();
    if (!mounted) return;
    AppSnack.show(context, ref, 'Workout template updated');
  }

  // ---------------------------------------------------------------------------
  // Finishing
  // ---------------------------------------------------------------------------

  Future<void> _finishWorkout() async {
    final state = ref.read(workoutProvider);
    final session = state.session;
    if (session == null || !state.isRunning) return;

    final summary = _WorkoutSummary.of(session);
    final minutes = (state.elapsedSeconds / 60).ceil();
    final wins = _collectWins(session, state.placeholders);
    final remaining = summary.totalSets - summary.completedSets;

    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Finish workout?',
      message: remaining == 0
          ? '${AppFormat.duration(minutes)} · ${summary.completedSets} sets · '
              '${AppFormat.compact(summary.tonnage)} kg lifted.'
          : '$remaining of ${summary.totalSets} sets are still empty. They are '
              'saved as they are.',
      confirmLabel: 'Finish',
      icon: Icons.flag_rounded,
    );
    if (!confirmed || !mounted) return;

    HapticFeedback.heavyImpact();
    setState(() => _finishing = true);

    try {
      await ref.read(workoutProvider.notifier).finishWorkout();
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      AppSnack.show(
        context,
        ref,
        'Could not save the workout. Check your connection and try again.',
        isError: true,
      );
      return;
    }

    // Statistics read from one cached fetch — force it to refresh.
    if (mounted) ref.invalidate(workoutSessionsProvider);

    if (!mounted) return;
    await _showCompletionDialog(
      title: session.programTitle,
      minutes: minutes,
      summary: summary,
      wins: wins,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showCompletionDialog({
    required String title,
    required int minutes,
    required _WorkoutSummary summary,
    required List<_ProgressionWin> wins,
  }) {
    HapticFeedback.mediumImpact();

    return AppDialog.show<void>(
      context: context,
      ref: ref,
      title: 'Workout complete',
      message: title,
      icon: Icons.celebration_rounded,
      barrierDismissible: false,
      content: _CompletionContent(
        minutes: minutes,
        summary: summary,
        wins: wins,
      ),
      actionsBuilder: (context, t) => [
        Expanded(
          child: AppButton(
            label: 'Done',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Keys, summary and progression helpers (all local to this screen)
// ---------------------------------------------------------------------------

/// The four provider keys belonging to one set. The format has to match
/// `workout_provider.dart` exactly — placeholders, edited fields and the
/// controllers here all share it.
class _SetKeys {
  final String weight;
  final String reps;
  final String notes;
  final String rir;

  const _SetKeys._(this.weight, this.reps, this.notes, this.rir);

  factory _SetKeys(String exerciseName, int setIndex) {
    final base = '${exerciseName}_$setIndex';
    return _SetKeys._('w_$base', 'r_$base', 'n_$base', 'rir_$base');
  }
}

/// Live totals for the session, recomputed on every rebuild — cheap, and it
/// keeps the definition of "tonnage" in one place:
/// Σ weight × reps over non-warm-up sets with weight > 0 and reps > 0.
class _WorkoutSummary {
  final int totalSets;
  final int completedSets;
  final int workingSets;
  final int completedWorkingSets;
  final double tonnage;

  const _WorkoutSummary({
    required this.totalSets,
    required this.completedSets,
    required this.workingSets,
    required this.completedWorkingSets,
    required this.tonnage,
  });

  factory _WorkoutSummary.of(WorkoutSession session) {
    var totalSets = 0;
    var completedSets = 0;
    var workingSets = 0;
    var completedWorkingSets = 0;
    var tonnage = 0.0;

    for (final exercise in session.completedExercises) {
      for (final set in exercise.sets) {
        totalSets++;
        final done = set.weight > 0 && set.reps > 0;
        if (done) completedSets++;
        if (!set.isWarmUp) {
          workingSets++;
          if (done) {
            completedWorkingSets++;
            tonnage += set.weight * set.reps;
          }
        }
      }
    }

    return _WorkoutSummary(
      totalSets: totalSets,
      completedSets: completedSets,
      workingSets: workingSets,
      completedWorkingSets: completedWorkingSets,
      tonnage: tonnage,
    );
  }

  double get progress => totalSets == 0 ? 0 : completedSets / totalSets;
}

/// Rep/weight change vs the previous session for a single set.
class _Progression {
  final int? reps;
  final double? weight;

  const _Progression(this.reps, this.weight);

  bool get isEmpty => (reps == null || reps == 0) && (weight == null || weight == 0);
  bool get isWin => (reps != null && reps! > 0) || (weight != null && weight! > 0);
}

/// Prefers the progression the provider already stored on the set (it survives
/// an app restart) and falls back to comparing against the placeholders from
/// the previous session, mirroring the provider's own rules.
_Progression _progressionFor({
  required CompletedSet set,
  required String exerciseName,
  required int setIndex,
  required Map<String, dynamic> placeholders,
}) {
  if (set.isWarmUp) return const _Progression(null, null);

  var reps = set.progression;
  var weight = set.weightProgression;

  if (reps == null || weight == null) {
    final keys = _SetKeys(exerciseName, setIndex);
    final previousWeight = placeholders[keys.weight];
    final previousReps = placeholders[keys.reps];

    if (previousWeight is num && previousReps is num) {
      final previousWeightValue = previousWeight.toDouble();

      if (reps == null &&
          set.weight == previousWeightValue &&
          set.weight > 0 &&
          set.reps > 0) {
        final difference = set.reps - previousReps.toInt();
        if (difference != 0) reps = difference;
      }

      if (weight == null && set.weight > 0) {
        final difference = set.weight - previousWeightValue;
        if (difference != 0) weight = difference;
      }
    }
  }

  return _Progression(reps, weight);
}

class _ProgressionWin {
  final String exercise;
  final int setNumber;
  final _Progression progression;

  const _ProgressionWin({
    required this.exercise,
    required this.setNumber,
    required this.progression,
  });
}

/// Every set that beat the previous session, best weight jump first.
List<_ProgressionWin> _collectWins(
  WorkoutSession session,
  Map<String, dynamic> placeholders,
) {
  final wins = <_ProgressionWin>[];

  for (final exercise in session.completedExercises) {
    final warmUpSets = exercise.sets.where((s) => s.isWarmUp).length;
    for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
      final set = exercise.sets[setIndex];
      if (set.isWarmUp || set.weight <= 0 || set.reps <= 0) continue;

      final progression = _progressionFor(
        set: set,
        exerciseName: exercise.name,
        setIndex: setIndex,
        placeholders: placeholders,
      );
      if (!progression.isWin) continue;

      wins.add(
        _ProgressionWin(
          exercise: exercise.name,
          setNumber: setIndex - warmUpSets + 1,
          progression: progression,
        ),
      );
    }
  }

  wins.sort((a, b) {
    final double aWeight = a.progression.weight ?? 0;
    final double bWeight = b.progression.weight ?? 0;
    if (aWeight != bWeight) return bWeight.compareTo(aWeight);
    final int aReps = a.progression.reps ?? 0;
    final int bReps = b.progression.reps ?? 0;
    return bReps.compareTo(aReps);
  });

  return wins;
}

String _formatElapsed(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = remainder.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  const _StickyHeaderDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: extent, child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}

/// The frosted bar that hovers over the session: title, live timer, progress
/// and the finish action. Everything the user must be able to reach without
/// scrolling lives here.
class _ActiveWorkoutHeader extends ConsumerWidget {
  final double topInset;
  final String title;
  final int exerciseCount;
  final _WorkoutSummary summary;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onFinish;

  const _ActiveWorkoutHeader({
    required this.topInset,
    required this.title,
    required this.exerciseCount,
    required this.summary,
    required this.onBack,
    required this.onMenu,
    required this.onFinish,
  });

  static const double _topGap = 6;
  static const double _bottomGap = 10;
  static const double _rowA = 44;
  static const double _rowGap = 10;
  static const double _rowB = 40;

  /// 12 + 44 + 10 + 40 + 12 of glass padding and rows, plus the outer gaps.
  static const double totalHeight =
      _topGap + AppSpacing.md * 2 + _rowA + _rowGap + _rowB + _bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: EdgeInsets.only(
        top: topInset + _topGap,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: _bottomGap,
      ),
      child: GlassSurface(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            SizedBox(
              height: _rowA,
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    size: 40,
                    iconSize: 16,
                    onPressed: onBack,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.heading(t).copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'} · '
                          '${summary.completedSets}/${summary.totalSets} sets',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption(t).copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const _TimerPill(),
                ],
              ),
            ),
            const SizedBox(height: _rowGap),
            SizedBox(
              height: _rowB,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 13,
                              color: t.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${AppFormat.compact(summary.tonnage)} kg lifted',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.mono(t, size: 12.5).copyWith(
                                  color: t.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _ProgressBar(progress: summary.progress),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppIconButton(
                    icon: Icons.more_horiz_rounded,
                    size: 38,
                    iconSize: 20,
                    onPressed: onMenu,
                    tooltip: 'Workout options',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Finish',
                    size: AppButtonSize.small,
                    onPressed: onFinish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The always-visible elapsed time. Watches only `elapsedSeconds`, so the
/// once-a-second tick never rebuilds the exercise list underneath it.
class _TimerPill extends ConsumerWidget {
  const _TimerPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final seconds = ref.watch(workoutProvider.select((s) => s.elapsedSeconds));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: t.primaryWash,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: t.primaryWashOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: t.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _formatElapsed(seconds),
            style: AppType.mono(t, size: 17, weight: FontWeight.w800)
                .copyWith(color: t.primary),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final value = progress.clamp(0.0, 1.0);

    return SizedBox(
      height: 6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Container(
                width: width,
                height: 6,
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              AnimatedContainer(
                duration: AppMotion.normal,
                curve: AppMotion.standard,
                width: width * value,
                height: 6,
                decoration: BoxDecoration(
                  gradient: t.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise card
// ---------------------------------------------------------------------------

class _ExerciseCard extends ConsumerWidget {
  final int exerciseIndex;
  final CompletedExercise exercise;
  final Map<String, TextEditingController> controllers;
  final bool canRemoveExercise;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveLastSet;
  final ValueChanged<int> onRemoveSet;
  final VoidCallback onRemoveExercise;

  const _ExerciseCard({
    required this.exerciseIndex,
    required this.exercise,
    required this.controllers,
    required this.canRemoveExercise,
    required this.onAddSet,
    required this.onRemoveLastSet,
    required this.onRemoveSet,
    required this.onRemoveExercise,
  });

  String get _letter => exerciseIndex < 26
      ? String.fromCharCode(65 + exerciseIndex)
      : '${exerciseIndex + 1}';

  void _showMenu(BuildContext context, WidgetRef ref) {
    AppSheet.actions(
      context: context,
      ref: ref,
      title: exercise.name,
      actions: [
        SheetAction(
          icon: Icons.add_rounded,
          label: 'Add set',
          description: 'Append a working set',
          onTap: onAddSet,
        ),
        if (exercise.sets.length > 1)
          SheetAction(
            icon: Icons.remove_circle_outline_rounded,
            label: 'Remove last set',
            onTap: onRemoveLastSet,
          ),
        if (canRemoveExercise)
          SheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'Remove exercise',
            description: 'Drops it from this session only',
            destructive: true,
            onTap: onRemoveExercise,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final showRIR = ref.watch(workoutSettingsProvider).showRIR;

    final warmUpSets = exercise.sets.where((s) => s.isWarmUp).length;
    final workingSets = exercise.sets.length - warmUpSets;
    final done = exercise.sets
        .where((s) => s.weight > 0 && s.reps > 0)
        .length;
    final complete = done == exercise.sets.length && exercise.sets.isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: complete ? null : t.primaryWash,
                  gradient: complete ? t.primaryGradientDiagonal : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: complete
                      ? null
                      : Border.all(color: t.primaryWashOutline),
                ),
                child: complete
                    ? Icon(Icons.check_rounded, size: 20, color: t.onPrimary)
                    : Text(
                        _letter,
                        style: AppType.heading(t).copyWith(
                          fontSize: 15,
                          color: t.primary,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.heading(t),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        '$workingSets working ${workingSets == 1 ? 'set' : 'sets'}',
                        if (warmUpSets > 0) '$warmUpSets warm-up',
                        '$done/${exercise.sets.length} done',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption(t),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppIconButton(
                icon: Icons.more_horiz_rounded,
                size: 38,
                iconSize: 20,
                filled: false,
                onPressed: () => _showMenu(context, ref),
                tooltip: 'Exercise options',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SetTableHeader(showRIR: showRIR),
          for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++)
            ..._buildSetSection(context, t, setIndex),
          const SizedBox(height: AppSpacing.xs),
          Pressable(
            onTap: onAddSet,
            scale: 0.98,
            haptic: HapticStrength.selection,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 17, color: t.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Add set',
                    style: AppType.secondary(t).copyWith(
                      color: t.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSetSection(
    BuildContext context,
    AppColors t,
    int setIndex,
  ) {
    final set = exercise.sets[setIndex];
    final previous = setIndex == 0 ? null : exercise.sets[setIndex - 1];
    final warmUpSets = exercise.sets.where((s) => s.isWarmUp).length;

    final startsWarmUpGroup =
        set.isWarmUp && (previous == null || !previous.isWarmUp);
    final startsWorkingGroup =
        !set.isWarmUp && previous != null && previous.isWarmUp;

    return [
      if (startsWarmUpGroup)
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              AppBadge(
                label: 'Warm-up',
                color: t.warning,
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),
        ),
      if (startsWorkingGroup)
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            children: [
              AppBadge(
                label: 'Working sets',
                color: t.primary,
                icon: Icons.fitness_center_rounded,
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: _SetRow(
          key: ValueKey('set_${exercise.name}_$setIndex'),
          exerciseIndex: exerciseIndex,
          exerciseName: exercise.name,
          setIndex: setIndex,
          set: set,
          warmUpSets: warmUpSets,
          controllers: controllers,
          onDeleteSet:
              exercise.sets.length > 1 ? () => onRemoveSet(setIndex) : null,
        ),
      ),
    ];
  }
}

/// Column labels for the set table. Uses the same widths/flexes as [_SetRow],
/// so the numbers line up in a single readable column.
class _SetTableHeader extends ConsumerWidget {
  final bool showRIR;

  const _SetTableHeader({required this.showRIR});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final style = AppType.overline(t).copyWith(
      fontSize: 9.5,
      color: t.textTertiary,
      letterSpacing: 0.9,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: _SetRow.badgeWidth,
            child: Text('SET', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text('KG', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text('REPS', style: style, textAlign: TextAlign.center),
          ),
          if (showRIR) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: Text('RIR', style: style, textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: _SetRow.checkWidth,
            child: Icon(Icons.check_rounded, size: 13, color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Set row
// ---------------------------------------------------------------------------

/// One logged set.
///
/// Interactions preserved from the previous version:
///  * swipe left/right to copy last session's values into the row,
///  * per-field edited tracking (typing marks, clearing unmarks),
///  * progression vs the previous session,
///  * remove-set.
class _SetRow extends ConsumerStatefulWidget {
  final int exerciseIndex;
  final String exerciseName;
  final int setIndex;
  final CompletedSet set;
  final int warmUpSets;
  final Map<String, TextEditingController> controllers;
  final VoidCallback? onDeleteSet;

  const _SetRow({
    super.key,
    required this.exerciseIndex,
    required this.exerciseName,
    required this.setIndex,
    required this.set,
    required this.warmUpSets,
    required this.controllers,
    this.onDeleteSet,
  });

  static const double badgeWidth = 38;
  static const double checkWidth = 46;

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow>
    with SingleTickerProviderStateMixin {
  static const double _maxSwipe = 80;

  double _swipeOffset = 0;
  late final AnimationController _animationController = AnimationController(
    duration: AppMotion.slow,
    vsync: this,
  );
  // Driven through `drive`/`chain` rather than `CurvedAnimation`: a
  // CurvedAnimation attaches a status listener to its parent on construction,
  // and this animation is rebuilt on every swipe, so listeners would pile up on
  // the controller for the lifetime of the row.
  late Animation<double> _offsetAnimation = _animationController.drive(
    Tween<double>(begin: 0, end: 0).chain(
      CurveTween(curve: AppMotion.standard),
    ),
  );

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  _SetKeys get _keys => _SetKeys(widget.exerciseName, widget.setIndex);

  WorkoutStateNotifier get _notifier => ref.read(workoutProvider.notifier);

  TextEditingController? _controller(String key) => widget.controllers[key];

  // --- placeholders -----------------------------------------------------

  bool _hasPlaceholders(Map<String, dynamic> placeholders) {
    final keys = _keys;
    final weight = placeholders[keys.weight];
    final reps = placeholders[keys.reps];
    final notes = placeholders[keys.notes];
    final rir = placeholders[keys.rir];
    return (weight is num && weight > 0) ||
        (reps is num && reps > 0) ||
        (notes is String && notes.isNotEmpty) ||
        (rir is num && rir > 0);
  }

  /// Copies the previous session's numbers into this row — the payoff of the
  /// swipe gesture and of the repeat button.
  void _fillFromLastSession() {
    final placeholders = ref.read(workoutProvider).placeholders;
    final keys = _keys;

    double? weight;
    int? reps;
    String? notes;
    int? rir;
    final editedKeys = <String>[];

    final placeholderWeight = placeholders[keys.weight];
    if (placeholderWeight is num && placeholderWeight > 0) {
      weight = placeholderWeight.toDouble();
      _controller(keys.weight)?.text = AppFormat.weight(weight);
      editedKeys.add(keys.weight);
    }

    final placeholderReps = placeholders[keys.reps];
    if (placeholderReps is num && placeholderReps > 0) {
      reps = placeholderReps.toInt();
      _controller(keys.reps)?.text = reps.toString();
      editedKeys.add(keys.reps);
    }

    final placeholderNotes = placeholders[keys.notes];
    if (placeholderNotes is String && placeholderNotes.isNotEmpty) {
      notes = placeholderNotes;
      _controller(keys.notes)?.text = notes;
      editedKeys.add(keys.notes);
    }

    final placeholderRir = placeholders[keys.rir];
    if (placeholderRir is num && placeholderRir > 0) {
      rir = placeholderRir.toInt();
      _controller(keys.rir)?.text = rir.toString();
      editedKeys.add(keys.rir);
    }

    if (editedKeys.isEmpty) return;

    HapticFeedback.mediumImpact();
    _notifier.markFieldsEdited(editedKeys);
    _notifier.updateSetData(
      widget.exerciseIndex,
      widget.setIndex,
      weight: weight,
      reps: reps,
      notes: notes,
      rir: rir,
    );
  }

  void _clearSet() {
    final keys = _keys;
    for (final key in [keys.weight, keys.reps, keys.notes, keys.rir]) {
      _controller(key)?.clear();
      _notifier.unmarkFieldEdited(key);
    }
    _notifier.updateSetData(
      widget.exerciseIndex,
      widget.setIndex,
      weight: 0,
      reps: 0,
      notes: '',
      rir: 0,
    );
    HapticFeedback.selectionClick();
  }

  // --- swipe ------------------------------------------------------------

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _swipeOffset =
          (_swipeOffset + details.delta.dx).clamp(-_maxSwipe, _maxSwipe);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    final horizontalVelocity = details.velocity.pixelsPerSecond.dx.abs();
    final verticalVelocity = details.velocity.pixelsPerSecond.dy.abs();
    final isHorizontalSwipe = horizontalVelocity > verticalVelocity;
    final hasEnoughVelocity = horizontalVelocity > 100;
    final hasEnoughDistance = _swipeOffset.abs() > 15;

    if (isHorizontalSwipe && (hasEnoughVelocity || hasEnoughDistance)) {
      if (_hasPlaceholders(ref.read(workoutProvider).placeholders)) {
        _fillFromLastSession();
      }
    }

    _offsetAnimation = _animationController.drive(
      Tween<double>(begin: _swipeOffset, end: 0).chain(
        CurveTween(curve: AppMotion.standard),
      ),
    );
    _animationController.forward(from: 0).then((_) {
      if (mounted) setState(() => _swipeOffset = 0);
    });
  }

  // --- per-set menu -----------------------------------------------------

  void _showSetMenu(bool canFill) {
    final label = widget.set.isWarmUp
        ? 'Warm-up set ${widget.setIndex + 1}'
        : 'Set ${widget.setIndex - widget.warmUpSets + 1}';

    AppSheet.actions(
      context: context,
      ref: ref,
      title: label,
      actions: [
        if (canFill)
          SheetAction(
            icon: Icons.replay_rounded,
            label: 'Same as last session',
            description: 'Copy weight, reps and notes from last time',
            onTap: _fillFromLastSession,
          ),
        SheetAction(
          icon: Icons.backspace_outlined,
          label: 'Clear set',
          description: 'Empty every field in this row',
          onTap: _clearSet,
        ),
        if (widget.onDeleteSet != null)
          SheetAction(
            icon: Icons.remove_circle_outline_rounded,
            label: 'Remove set',
            destructive: true,
            onTap: widget.onDeleteSet!,
          ),
      ],
    );
  }

  // --- inputs -----------------------------------------------------------

  void _onWeightChanged(String value) {
    final keys = _keys;
    if (value.isEmpty) {
      _notifier.unmarkFieldEdited(keys.weight);
    } else {
      _notifier.markFieldEdited(keys.weight);
    }
    final weight = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    final currentReps =
        int.tryParse(_controller(keys.reps)?.text ?? '') ?? widget.set.reps;
    _notifier.updateSetData(
      widget.exerciseIndex,
      widget.setIndex,
      weight: weight,
      reps: currentReps,
    );
  }

  void _onRepsChanged(String value) {
    final keys = _keys;
    if (value.isEmpty) {
      _notifier.unmarkFieldEdited(keys.reps);
    } else {
      _notifier.markFieldEdited(keys.reps);
    }
    final reps = int.tryParse(value) ?? 0;
    final currentWeight =
        double.tryParse((_controller(keys.weight)?.text ?? '').replaceAll(',', '.')) ??
            widget.set.weight;
    _notifier.updateSetData(
      widget.exerciseIndex,
      widget.setIndex,
      weight: currentWeight,
      reps: reps,
    );
  }

  void _onRirChanged(String value) {
    final keys = _keys;
    if (value.isEmpty) {
      _notifier.unmarkFieldEdited(keys.rir);
    } else {
      _notifier.markFieldEdited(keys.rir);
    }
    _notifier.updateSetData(
      widget.exerciseIndex,
      widget.setIndex,
      rir: int.tryParse(value) ?? 0,
    );
  }

  void _onNotesChanged(String value) {
    final keys = _keys;
    if (value.isEmpty) {
      _notifier.unmarkFieldEdited(keys.notes);
    } else {
      _notifier.markFieldEdited(keys.notes);
    }
    _notifier.updateSetData(
      widget.exerciseIndex,
      widget.setIndex,
      notes: value,
    );
  }

  // --- build ------------------------------------------------------------

  String _placeholderText(Map<String, dynamic> placeholders, String key) {
    final value = placeholders[key];
    if (value is num && value > 0) return AppFormat.weight(value);
    if (value is String && value.isNotEmpty) return value;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final settings = ref.watch(workoutSettingsProvider);
    final edited = ref.watch(workoutProvider.select((s) => s.editedFields));
    final placeholders =
        ref.watch(workoutProvider.select((s) => s.placeholders));

    final keys = _keys;
    final set = widget.set;
    final isWarmUp = set.isWarmUp;
    final complete = set.weight > 0 && set.reps > 0;
    final hasPlaceholders = _hasPlaceholders(placeholders);
    final canFill = hasPlaceholders && !complete;

    final progression = settings.showProgression
        ? _visibleProgression(edited, placeholders)
        : const _Progression(null, null);

    final accent = isWarmUp ? t.warning : t.primary;
    final numberStyle = AppType.mono(t, size: 19, weight: FontWeight.w700);

    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        final offset = _animationController.isAnimating
            ? _offsetAnimation.value
            : _swipeOffset;
        final swipeProgress = (offset.abs() / _maxSwipe).clamp(0.0, 1.0);
        final active = hasPlaceholders && swipeProgress > 0.05;

        final baseColor = complete ? t.primaryWash : t.surface;
        final background = active
            ? Color.lerp(baseColor, t.primaryWash, swipeProgress)!
            : baseColor;
        final borderColor = active && swipeProgress > 0.3
            ? t.primary.withValues(alpha: (0.25 + swipeProgress * 0.5).clamp(0.0, 1.0))
            : complete
                ? t.primaryWashOutline
                : t.outline;

        return Transform.translate(
          offset: Offset(offset, 0),
          child: GestureDetector(
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: borderColor,
                  width: active && swipeProgress > 0.3 ? 1.4 : 1.0,
                ),
                boxShadow: active && swipeProgress > 0.1
                    ? [
                        BoxShadow(
                          color: t.primary.withValues(alpha: 0.12 * swipeProgress),
                          blurRadius: 10 * swipeProgress,
                          spreadRadius: 1.5 * swipeProgress,
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _SetRow.badgeWidth,
                child: _SetBadge(
                  isWarmUp: isWarmUp,
                  label: isWarmUp
                      ? ''
                      : '${widget.setIndex - widget.warmUpSets + 1}',
                  accent: accent,
                  onTap: () => _showSetMenu(canFill),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: _ValueField(
                  theme: t,
                  controller: _controller(keys.weight),
                  hintText: _placeholderText(placeholders, keys.weight),
                  edited: edited.contains(keys.weight),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: numberStyle,
                  onChanged: _onWeightChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: _ValueField(
                  theme: t,
                  controller: _controller(keys.reps),
                  hintText: _placeholderText(placeholders, keys.reps),
                  edited: edited.contains(keys.reps),
                  keyboardType: TextInputType.number,
                  style: numberStyle,
                  onChanged: _onRepsChanged,
                ),
              ),
              if (settings.showRIR) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: _ValueField(
                    theme: t,
                    controller: _controller(keys.rir),
                    hintText: _placeholderText(placeholders, keys.rir),
                    edited: edited.contains(keys.rir),
                    keyboardType: TextInputType.number,
                    style: numberStyle.copyWith(fontSize: 17),
                    onChanged: _onRirChanged,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: _SetRow.checkWidth,
                child: Center(
                  child: _SetCheck(
                    complete: complete,
                    canFill: canFill,
                    accent: accent,
                    onTap: canFill ? _fillFromLastSession : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _NoteField(
            theme: t,
            controller: _controller(keys.notes),
            hintText: _placeholderText(placeholders, keys.notes),
            edited: edited.contains(keys.notes),
            onChanged: _onNotesChanged,
          ),
          if (!progression.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (progression.weight != null && progression.weight != 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: DeltaBadge(
                      delta: progression.weight!,
                      unit: 'kg',
                      fontSize: 11.5,
                    ),
                  ),
                if (progression.reps != null && progression.reps != 0)
                  DeltaBadge(
                    delta: progression.reps!,
                    unit: progression.reps!.abs() == 1 ? 'rep' : 'reps',
                    fontSize: 11.5,
                  ),
                const Spacer(),
                Text(
                  'vs last session',
                  style: AppType.caption(t).copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Same gate as before: progression is hidden for warm-ups, for rows the user
  /// has not touched yet and for rows that are still completely empty.
  _Progression _visibleProgression(
    Set<String> edited,
    Map<String, dynamic> placeholders,
  ) {
    final set = widget.set;
    if (set.isWarmUp) return const _Progression(null, null);

    final keys = _keys;
    final touched =
        edited.contains(keys.weight) || edited.contains(keys.reps);
    if (!touched) return const _Progression(null, null);
    if (set.weight == 0 && set.reps == 0) return const _Progression(null, null);

    return _progressionFor(
      set: set,
      exerciseName: widget.exerciseName,
      setIndex: widget.setIndex,
      placeholders: placeholders,
    );
  }
}

/// The set number (or a flame for warm-ups). Tapping opens the per-set menu.
class _SetBadge extends ConsumerWidget {
  final bool isWarmUp;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _SetBadge({
    required this.isWarmUp,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Pressable(
      onTap: onTap,
      scale: 0.9,
      haptic: HapticStrength.selection,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: t.isDark ? 0.14 : 0.09),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: isWarmUp
            ? Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: accent,
              )
            : Text(
                label,
                style: AppType.mono(t, size: 15, weight: FontWeight.w800)
                    .copyWith(color: accent),
              ),
      ),
    );
  }
}

/// Completion affordance. Solid + ticked once the set has weight and reps;
/// a repeat button while the row is empty and last session's numbers exist.
class _SetCheck extends ConsumerWidget {
  final bool complete;
  final bool canFill;
  final Color accent;
  final VoidCallback? onTap;

  const _SetCheck({
    required this.complete,
    required this.canFill,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final Color background;
    final Color foreground;
    final Border? border;

    if (complete) {
      background = accent;
      foreground = AppColors.contrastOn(accent);
      border = null;
    } else if (canFill) {
      background = t.primaryWash;
      foreground = t.primary;
      border = Border.all(color: t.primaryWashOutline);
    } else {
      background = t.card;
      foreground = t.textTertiary;
      border = Border.all(color: t.outline);
    }

    return Pressable(
      onTap: onTap,
      scale: 0.88,
      haptic: HapticStrength.medium,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        width: 46,
        height: 52,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: border,
        ),
        child: Icon(
          complete
              ? Icons.check_rounded
              : canFill
                  ? Icons.replay_rounded
                  : Icons.check_rounded,
          size: 22,
          color: foreground,
        ),
      ),
    );
  }
}

/// A big, centred numeric input. Text is full-contrast once the user has
/// edited the field and muted while it is only showing last session's hint.
class _ValueField extends StatelessWidget {
  final AppColors theme;
  final TextEditingController? controller;
  final String hintText;
  final bool edited;
  final TextInputType keyboardType;
  final TextStyle style;
  final ValueChanged<String> onChanged;

  const _ValueField({
    required this.theme,
    required this.controller,
    required this.hintText,
    required this.edited,
    required this.keyboardType,
    required this.style,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: t.outline),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.next,
      maxLines: 1,
      cursorColor: t.primary,
      style: style.copyWith(
        color: edited ? t.text : t.textSecondary,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: t.card,
        hintText: hintText.isEmpty ? null : hintText,
        hintStyle: style.copyWith(color: t.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 14,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.primary, width: 1.8),
        ),
      ),
    );
  }
}

/// The free-text note under each set. Grows as it is typed into.
class _NoteField extends StatelessWidget {
  final AppColors theme;
  final TextEditingController? controller;
  final String hintText;
  final bool edited;
  final ValueChanged<String> onChanged;

  const _NoteField({
    required this.theme,
    required this.controller,
    required this.hintText,
    required this.edited,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: t.outline),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.sentences,
      minLines: 1,
      maxLines: null,
      cursorColor: t.primary,
      style: AppType.body(t).copyWith(
        fontSize: 13.5,
        color: edited ? t.text : t.textSecondary,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: t.card,
        prefixIcon: Icon(
          Icons.sticky_note_2_outlined,
          size: 16,
          color: t.textTertiary,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        hintText: hintText.isEmpty ? 'Note' : hintText,
        hintStyle: AppType.secondary(t).copyWith(
          fontSize: 13.5,
          color: t.textTertiary,
        ),
        contentPadding: const EdgeInsets.only(
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.primary, width: 1.6),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer summary
// ---------------------------------------------------------------------------

class _SessionSummaryCard extends ConsumerWidget {
  final _WorkoutSummary summary;

  const _SessionSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final seconds = ref.watch(workoutProvider.select((s) => s.elapsedSeconds));

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Overline('This session'),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  icon: Icons.timer_outlined,
                  label: 'Elapsed',
                  value: _formatElapsed(seconds),
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.checklist_rounded,
                  label: 'Sets',
                  value: '${summary.completedSets}/${summary.totalSets}',
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.bolt_rounded,
                  label: 'Volume',
                  value: '${AppFormat.compact(summary.tonnage)} kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ProgressBar(progress: summary.progress),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.completedSets == summary.totalSets
                ? 'Every set logged. Nice work.'
                : '${summary.totalSets - summary.completedSets} sets left to log',
            style: AppType.caption(t),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: t.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption(t).copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.metric(t, size: 19),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Completion dialog content
// ---------------------------------------------------------------------------

class _CompletionContent extends ConsumerWidget {
  final int minutes;
  final _WorkoutSummary summary;
  final List<_ProgressionWin> wins;

  const _CompletionContent({
    required this.minutes,
    required this.summary,
    required this.wins,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final topWins = wins.take(3).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: t.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  icon: Icons.timer_outlined,
                  label: 'Time',
                  value: AppFormat.duration(minutes),
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.checklist_rounded,
                  label: 'Sets',
                  value: '${summary.completedSets}',
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.bolt_rounded,
                  label: 'Volume',
                  value: '${AppFormat.compact(summary.tonnage)} kg',
                ),
              ),
            ],
          ),
        ),
        if (topWins.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Overline(
              wins.length == 1
                  ? '1 set beat last session'
                  : '${wins.length} sets beat last session',
            ),
          ),
          for (final win in topWins)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${win.exercise} · set ${win.setNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.secondary(t),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (win.progression.weight != null &&
                      win.progression.weight != 0)
                    DeltaBadge(
                      delta: win.progression.weight!,
                      unit: 'kg',
                      compact: true,
                      fontSize: 11.5,
                    )
                  else if (win.progression.reps != null)
                    DeltaBadge(
                      delta: win.progression.reps!,
                      unit: win.progression.reps!.abs() == 1 ? 'rep' : 'reps',
                      compact: true,
                      fontSize: 11.5,
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets
// ---------------------------------------------------------------------------

class _ExerciseConfig {
  final int workingSets;
  final int warmUpSets;

  const _ExerciseConfig({required this.workingSets, required this.warmUpSets});
}

/// Set counts for a newly added exercise. Steppers instead of text fields —
/// nothing to focus, nothing to dispose, and far easier to hit one-handed.
class _ConfigureSetsSheet extends ConsumerStatefulWidget {
  final String exerciseName;

  const _ConfigureSetsSheet({required this.exerciseName});

  @override
  ConsumerState<_ConfigureSetsSheet> createState() =>
      _ConfigureSetsSheetState();
}

class _ConfigureSetsSheetState extends ConsumerState<_ConfigureSetsSheet> {
  int _workingSets = 3;
  int _warmUpSets = 0;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CountStepper(
            label: 'Working sets',
            hint: 'Counted towards your volume',
            value: _workingSets,
            min: 1,
            max: 15,
            onChanged: (value) => setState(() => _workingSets = value),
          ),
          Divider(height: AppSpacing.xxl, color: t.divider),
          _CountStepper(
            label: 'Warm-up sets',
            hint: 'Logged, but kept out of tonnage',
            value: _warmUpSets,
            min: 0,
            max: 5,
            onChanged: (value) => setState(() => _warmUpSets = value),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'Add ${widget.exerciseName}',
            icon: Icons.add_rounded,
            expand: true,
            onPressed: () => Navigator.of(context).pop(
              _ExerciseConfig(
                workingSets: _workingSets,
                warmUpSets: _warmUpSets,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountStepper extends ConsumerWidget {
  final String label;
  final String hint;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _CountStepper({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppType.heading(t)),
              const SizedBox(height: 2),
              Text(hint, style: AppType.secondary(t)),
            ],
          ),
        ),
        AppIconButton(
          icon: Icons.remove_rounded,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppType.metric(t, size: 22),
          ),
        ),
        AppIconButton(
          icon: Icons.add_rounded,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// Names a new template. Owns its controller and disposes it.
class _WorkoutNameSheet extends ConsumerStatefulWidget {
  const _WorkoutNameSheet();

  @override
  ConsumerState<_WorkoutNameSheet> createState() => _WorkoutNameSheetState();
}

class _WorkoutNameSheetState extends ConsumerState<_WorkoutNameSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      AppSnack.show(context, ref, 'Please enter a workout name', isError: true);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              cursorColor: t.primary,
              style: AppType.body(t),
              decoration: InputDecoration(
                hintText: 'Workout name',
                hintStyle:
                    AppType.secondary(t).copyWith(color: t.textTertiary),
                filled: true,
                fillColor: t.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: t.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: t.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: t.primary, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Save workout',
              icon: Icons.bookmark_add_rounded,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nothing running
// ---------------------------------------------------------------------------

/// Shown when the screen is opened without a live session. If the provider is
/// holding an abandoned session (older than 8 hours) it is offered here rather
/// than silently dropped.
class _InactiveWorkoutView extends ConsumerWidget {
  final WorkoutSession? stale;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const _InactiveWorkoutView({
    required this.stale,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final staleSession = stale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            0,
          ),
          child: Row(
            children: [
              AppIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 40,
                iconSize: 16,
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              ),
            ],
          ),
        ),
        Expanded(
          child: staleSession == null
              ? EmptyState(
                  icon: Icons.self_improvement_rounded,
                  title: 'No workout in progress',
                  message:
                      'Start a program from the home screen and it will show '
                      'up here.',
                  actionLabel: 'Go back',
                  onAction: () => Navigator.of(context).maybePop(),
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    child: FadeSlideIn(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                IconBadge(
                                  icon: Icons.history_rounded,
                                  color: t.warning,
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Unfinished workout',
                                        style: AppType.heading(t),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        staleSession.programTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppType.secondary(t),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'This session was left running '
                              '${AppFormat.relativeDate(staleSession.date).toLowerCase()}. '
                              'Pick it up where you left off, or throw it away.',
                              style: AppType.secondary(t),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton.secondary(
                                    label: 'Discard',
                                    onPressed: onDiscard,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: AppButton(
                                    label: 'Resume',
                                    icon: Icons.play_arrow_rounded,
                                    onPressed: onResume,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
