import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/master_exercise_model.dart';
import '../models/workout_session_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/rest_timer_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../utils/placeholder_history.dart' show isSetLogged;
import '../utils/workout_comparison.dart';
import '../widgets/workout_comparison_list.dart';
import '../widgets/ui/ui.dart';
import 'choose_category_screen.dart';

/// ---------------------------------------------------------------------------
/// The live workout screen.
///
/// Designed for one-handed use at a rack: one slim frosted bar with the
/// elapsed time and the finish action, exercise cards holding a compact set
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

  /// Set between "finish/discard confirmed" and leaving the screen. While it
  /// is non-null the page shows this message instead of the session, so it
  /// never flashes the empty state while the provider resets.
  String? _exitMessage;

  /// Whether the list has moved off its top — the header only lays its scrim
  /// over the status bar once there is content to hide under it.
  final ValueNotifier<bool> _scrolled = ValueNotifier<bool>(false);

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
    _scrolled.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    // Only the page itself — every text field scrolls its own line too.
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical) {
      _scrolled.value = notification.metrics.pixels > 0.5;
    }
    return false;
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
          // An edited 0 is a deliberate bodyweight set — show it, or the
          // field falls back to last session's hint after a rebuild.
          text: edited.contains(keys.weight)
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
    // Structural changes (add/remove set or exercise, session finished) arrive
    // here first, before the rebuild that renders them.
    ref.listen<ActiveWorkoutState>(workoutProvider, _onWorkoutStateChanged);

    final exitMessage = _exitMessage;
    if (exitMessage != null) {
      return AppPage(
        child: Center(child: LoadingState(message: exitMessage)),
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
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;
    final keyboardOpen = media.viewInsets.bottom > 0;

    final showRestTimer =
        ref.watch(workoutSettingsProvider.select((s) => s.showRestTimer));
    final restTimerVisible = showRestTimer && !keyboardOpen;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Leaving the screen never stops the workout — just flush the state.
        ref.read(workoutProvider.notifier).saveCurrentState();
      },
      // Around the whole page, not the pill: the buzz at the end of a rest must
      // still come while the keyboard (which hides the pill) is up.
      child: RestTargetHaptics(
        enabled: showRestTimer,
        child: AppPage(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyHeaderDelegate(
                          extent: topInset + _ActiveWorkoutHeader.totalHeight,
                          child: _ActiveWorkoutHeader(
                            topInset: topInset,
                            title: session.programTitle,
                            summary: summary,
                            scrolled: _scrolled,
                            onBack: () => Navigator.of(context).maybePop(),
                            onMenu: _showWorkoutMenu,
                            onFinish: _finishWorkout,
                          ),
                        ),
                      ),
                      if (exercises.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.huge),
                            child: EmptyState(
                              icon: Icons.fitness_center_rounded,
                              title: 'No exercises yet',
                              message:
                                  'Add an exercise to start logging sets.',
                              actionLabel: 'Add exercise',
                              onAction: _addExercise,
                            ),
                          ),
                        )
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenH,
                            AppSpacing.sm,
                            AppSpacing.screenH,
                            0,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final exercise = exercises[index];
                                return Padding(
                                  key: ValueKey('exercise_$index'),
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: FadeSlideIn(
                                    index: index,
                                    child: _ExerciseCard(
                                      exerciseIndex: index,
                                      exercise: exercise,
                                      controllers: _controllers,
                                      canRemoveExercise: exercises.length > 1,
                                      onAddSet: () => _addSet(index),
                                      onRemoveLastSet: () => _removeSet(
                                        index,
                                        exercise.sets.length - 1,
                                      ),
                                      onRemoveSet: (setIndex) =>
                                          _removeSet(index, setIndex),
                                      onRemoveExercise: () =>
                                          _removeExercise(index),
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
                              // Scrolled to the end, the button sits a clear
                              // gap above the rest timer and the fade behind
                              // it. With the timer switched off there is
                              // nothing to clear, so it does not sit above a
                              // band of dead space.
                              AppSpacing.lg +
                                  (showRestTimer
                                      ? RestTimerBar.clearance
                                      : AppSpacing.lg) +
                                  bottomInset,
                            ),
                            child: AppButton.outline(
                              label: 'Add exercise',
                              icon: Icons.add_rounded,
                              expand: true,
                              onPressed: _addExercise,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // The rest timer floats over the list so it is reachable
              // without scrolling. Hidden while the keyboard is up, where it
              // would sit on top of the number pad the user is aiming at, and
              // switched off entirely from Settings for people who do not time
              // their rests.
              if (restTimerVisible)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RestTimerBar(),
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

    // Inputs, hints and edited flags are all keyed by exercise name, so the
    // same exercise twice in one session would share its fields.
    final alreadyInSession = ref
            .read(workoutProvider)
            .session
            ?.completedExercises
            .any((e) => e.name == exerciseName) ??
        false;
    if (alreadyInSession) {
      AppSnack.show(
        context,
        ref,
        '$exerciseName is already in this workout. Add sets to it instead.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

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
    ref.read(restTimerProvider.notifier).stop();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  // ---------------------------------------------------------------------------
  // Workout options
  // ---------------------------------------------------------------------------

  void _showWorkoutMenu() {
    final session = ref.read(workoutProvider).session;
    if (session == null) return;
    FocusScope.of(context).unfocus();

    AppSheet.actions(
      context: context,
      ref: ref,
      title: 'Workout options',
      actions: [
        SheetAction(
          icon: Icons.add_rounded,
          label: 'Add exercise',
          onTap: _addExercise,
        ),
        SheetAction(
          icon: Icons.save_rounded,
          label: 'Update template',
          description: 'Save these exercises and set counts to '
              '"${session.programTitle}"',
          onTap: _updateOriginalTemplate,
        ),
        SheetAction(
          icon: Icons.bookmark_add_rounded,
          label: 'Save as new workout',
          description: 'Create a new template from these exercises',
          onTap: _showSaveAsWorkoutSheet,
        ),
        SheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Discard workout',
          description: 'Delete this session without saving it',
          destructive: true,
          onTap: _confirmDiscardWorkout,
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

    try {
      await ref
          .read(workoutProvider.notifier)
          .saveActiveWorkoutAsTemplate(name, overwrite: false);
    } catch (_) {
      if (!mounted) return;
      AppSnack.show(
        context,
        ref,
        'Could not save the workout. Try again.',
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    AppSnack.show(context, ref, 'Workout saved as "$name"');
  }

  Future<void> _updateOriginalTemplate() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Update template?',
      message: 'The original workout template is replaced with the exercises '
          'and sets you have right now.',
      confirmLabel: 'Update',
      icon: Icons.save_rounded,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(workoutProvider.notifier).updateOriginalTemplate();
    } catch (_) {
      if (!mounted) return;
      AppSnack.show(
        context,
        ref,
        'Could not update the template. Try again.',
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    AppSnack.show(context, ref, 'Workout template updated');
  }

  Future<void> _confirmDiscardWorkout() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Discard workout?',
      message: 'Everything logged in this session is deleted and nothing is '
          'added to your history.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _discardWorkout();
  }

  /// Throws the live session away without saving it. Callers confirm first.
  Future<void> _discardWorkout() async {
    HapticFeedback.mediumImpact();
    setState(() => _exitMessage = 'Discarding workout…');
    // Read before the await: back can dispose this screen while it runs, and
    // `ref` is unusable after that.
    final container = ProviderScope.containerOf(context, listen: false);

    try {
      await ref.read(workoutProvider.notifier).discardWorkout();
    } catch (_) {
      if (!mounted) return;
      setState(() => _exitMessage = null);
      AppSnack.show(
        context,
        ref,
        'Could not discard the workout. Try again.',
        isError: true,
      );
      return;
    }

    // The rest belongs to the session that was just thrown away.
    container.read(restTimerProvider.notifier).stop();

    if (!mounted) return;
    AppSnack.show(context, ref, 'Workout discarded');
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Finishing
  // ---------------------------------------------------------------------------

  Future<void> _finishWorkout() async {
    final state = ref.read(workoutProvider);
    final session = state.session;
    if (session == null || !state.isRunning) return;
    FocusScope.of(context).unfocus();

    final summary = _WorkoutSummary.of(session);

    // Nothing done means nothing to save (the provider would discard it
    // anyway) — say so and offer to throw the session away.
    if (summary.completedSets == 0) {
      final discard = await AppDialog.confirm(
        context: context,
        ref: ref,
        title: 'Nothing logged yet',
        message: 'No set has reps yet, so there is nothing to save. '
            'Discard this workout?',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep going',
        destructive: true,
      );
      if (!discard || !mounted) return;
      await _discardWorkout();
      return;
    }

    final minutes = (state.elapsedSeconds / 60).ceil();
    final done = summary.completedSets;
    final skipped = summary.unloggedSets;

    // Always the same lead line; unlogged sets get a short line of their own
    // instead of a run-on sentence that wraps a lone word onto a new line.
    final lead = '${AppFormat.duration(minutes)} · '
        '$done ${done == 1 ? 'set' : 'sets'} logged.';
    final skippedLine = skipped == 0
        ? ''
        : '\n$skipped empty ${skipped == 1 ? 'set' : 'sets'} won\'t be saved.';

    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Finish workout?',
      message: '$lead$skippedLine',
      confirmLabel: 'Finish',
      cancelLabel: 'Keep going',
      icon: Icons.flag_rounded,
    );
    if (!confirmed || !mounted) return;

    HapticFeedback.heavyImpact();
    setState(() => _exitMessage = 'Saving your workout…');
    // Read before the await: back can dispose this screen while it saves, and
    // the rest timer and stats must be dealt with either way.
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(workoutProvider.notifier);

    // Measured before saving — finishing releases the history it compares
    // against. Almost always already loaded (the hints came from it); offline
    // it gives up quickly rather than holding the save hostage.
    final history = await notifier
        .comparisonHistory()
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => const <WorkoutSession>[],
        )
        .catchError((Object _) => const <WorkoutSession>[]);
    final comparison = compareWithHistory(session: session, history: history);

    try {
      await notifier.finishWorkout();
    } catch (_) {
      if (!mounted) return;
      setState(() => _exitMessage = null);
      AppSnack.show(
        context,
        ref,
        'Could not save the workout. Check your connection and try again.',
        isError: true,
      );
      return;
    }

    // The rest belongs to the session that just ended.
    container.read(restTimerProvider.notifier).stop();

    // Statistics read from one cached fetch — force it to refresh.
    container.invalidate(workoutSessionsProvider);

    if (!mounted) return;
    await _showCompletionDialog(
      title: session.programTitle,
      minutes: minutes,
      summary: summary,
      comparison: comparison,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showCompletionDialog({
    required String title,
    required int minutes,
    required _WorkoutSummary summary,
    required SessionComparison comparison,
  }) {
    HapticFeedback.mediumImpact();

    return AppDialog.show<void>(
      context: context,
      ref: ref,
      title: 'Workout complete',
      message: title,
      icon: Icons.celebration_rounded,
      // Done reads in the success tone, not the accent.
      iconColor: ref.read(themeProvider).success,
      barrierDismissible: false,
      content: _CompletionContent(
        minutes: minutes,
        summary: summary,
        comparison: comparison,
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

/// A set is done once it has reps. Weight may stay 0 — that is a bodyweight
/// set. The single definition behind every count, style and the rest timer on
/// this screen; it delegates to the app-wide rule, which is also what decides
/// which sets the provider keeps when the workout is saved.
bool _isSetDone(CompletedSet set) => isSetLogged(set);

/// Nothing entered at all.
bool _isSetEmpty(CompletedSet set) => set.reps == 0 && set.weight == 0;

/// Last session's values (the grey hints) and the set table's column labels.
/// Readable at arm's length — about 3.5:1 or better on the input well in every
/// palette — yet plainly quieter than a typed value, which is full-contrast
/// text at a heavier weight.
Color _hintTone(AppColors t) =>
    Color.lerp(t.textSecondary, t.surface, t.isDark ? 0.25 : 0.12)!;

/// The faint band behind a finished working set. Just enough to scan which
/// sets are done; the numbers stay the loudest thing on the row.
Color _doneWash(AppColors t) => t.successBand;

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

/// Live set counts for the session, recomputed on every rebuild — cheap.
class _WorkoutSummary {
  final int totalSets;

  /// Sets that are done ([_isSetDone]) — the ones finishing saves.
  final int completedSets;

  /// Done sets without the warm-ups — what history and the comparison with
  /// last time count.
  final int completedWorkingSets;

  const _WorkoutSummary({
    required this.totalSets,
    required this.completedSets,
    required this.completedWorkingSets,
  });

  factory _WorkoutSummary.of(WorkoutSession session) {
    var totalSets = 0;
    var completedSets = 0;
    var completedWorkingSets = 0;

    for (final exercise in session.completedExercises) {
      for (final set in exercise.sets) {
        totalSets++;
        if (!_isSetDone(set)) continue;
        completedSets++;
        if (!set.isWarmUp) completedWorkingSets++;
      }
    }

    return _WorkoutSummary(
      totalSets: totalSets,
      completedSets: completedSets,
      completedWorkingSets: completedWorkingSets,
    );
  }

  /// Sets without reps. The provider drops them when the workout is saved.
  int get unloggedSets => totalSets - completedSets;
}

/// Rep/weight change vs the previous session for a single set.
class _Progression {
  final int? reps;
  final double? weight;

  const _Progression(this.reps, this.weight);

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
    final previousReps = placeholders[keys.reps];

    if (previousReps is num) {
      // Reps without a weight hint means last time was a bodyweight set.
      final hintWeight = placeholders[keys.weight];
      final previousWeight = hintWeight is num ? hintWeight.toDouble() : 0.0;

      // Reps only compare at the same weight (0 = bodyweight both times).
      if (reps == null && set.weight == previousWeight && set.reps > 0) {
        final difference = set.reps - previousReps.toInt();
        if (difference != 0) reps = difference;
      }

      if (weight == null && set.weight > 0) {
        final difference = set.weight - previousWeight;
        if (difference != 0) weight = difference;
      }
    }
  }

  return _Progression(reps, weight);
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

/// The single frosted bar that hovers over the session: back, title with the
/// set count, the live clock, options and Finish. Everything the user must
/// reach without scrolling lives here — and nothing else does.
class _ActiveWorkoutHeader extends ConsumerWidget {
  final double topInset;
  final String title;
  final _WorkoutSummary summary;

  /// True once the list is scrolled — fades the scrim in.
  final ValueListenable<bool> scrolled;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onFinish;

  const _ActiveWorkoutHeader({
    required this.topInset,
    required this.title,
    required this.summary,
    required this.scrolled,
    required this.onBack,
    required this.onMenu,
    required this.onFinish,
  });

  static const double _rowHeight = 40;

  /// How far below the header the scrim keeps fading out, so content slides
  /// out of view gradually instead of being cut off at the pill's edge.
  static const double _scrimFade = AppSpacing.lg;

  /// [GlassSurface] draws a 1px border, and a bordered `Container` insets its
  /// child by the border on every side — so the glass is two pixels taller
  /// than its padding and row alone suggest.
  static const double _glassBorder = 1;

  /// Gap above the glass + border + padding + the row + gap below the glass.
  static const double totalHeight = AppSpacing.sm +
      _glassBorder * 2 +
      AppSpacing.xs * 2 +
      _rowHeight +
      AppSpacing.sm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final extent = topInset + totalHeight;

    final pill = Padding(
      padding: EdgeInsets.only(
        top: topInset + AppSpacing.sm,
        // Same gutter as the cards, so the pill's edges line up with theirs.
        left: AppSpacing.screenH,
        right: AppSpacing.screenH,
        bottom: AppSpacing.sm,
      ),
      child: GlassSurface(
        radius: AppRadius.pill,
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: SizedBox(
          height: _rowHeight,
          child: Row(
            children: [
              AppIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: _rowHeight,
                iconSize: 16,
                filled: false,
                onPressed: onBack,
                tooltip: 'Back',
              ),
              const SizedBox(width: AppSpacing.xs),
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
                      style: AppType.heading(t).copyWith(fontSize: 15.5),
                    ),
                    Text(
                      '${summary.completedSets}/${summary.totalSets} sets',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption(t).copyWith(
                        fontSize: 11.5,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const _ElapsedClock(),
              const SizedBox(width: AppSpacing.xs),
              AppIconButton(
                icon: Icons.more_horiz_rounded,
                size: 36,
                iconSize: 20,
                filled: false,
                color: t.textSecondary,
                onPressed: onMenu,
                tooltip: 'Workout options',
              ),
              const SizedBox(width: AppSpacing.xs),
              // A pill, concentric with the bar around it.
              AppButton(
                label: 'Finish',
                size: AppButtonSize.small,
                radius: AppRadius.pill,
                onPressed: onFinish,
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The page itself (background and ambient glow, exactly as behind
        // the list) laid over the status bar and around the pill, fading out
        // just below it — scrolled content disappears under it cleanly
        // instead of passing beneath the clock or peeking out beside the bar.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: extent + _scrimFade,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: scrolled,
              builder: (context, isScrolled, child) => AnimatedOpacity(
                opacity: isScrolled ? 1 : 0,
                duration: AppMotion.fast,
                curve: AppMotion.standard,
                child: child,
              ),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    t.background,
                    t.background,
                    t.background.withValues(alpha: 0),
                  ],
                  stops: [
                    0,
                    (extent - AppSpacing.sm) / bounds.height,
                    1,
                  ],
                ).createShader(bounds),
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: t.background)),
                    AmbientBackground(theme: t),
                  ],
                ),
              ),
            ),
          ),
        ),
        pill,
      ],
    );
  }
}

/// The always-visible elapsed time. Watches only `elapsedSeconds`, so the
/// once-a-second tick never rebuilds the exercise list underneath it.
class _ElapsedClock extends ConsumerWidget {
  const _ElapsedClock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final seconds = ref.watch(workoutProvider.select((s) => s.elapsedSeconds));

    return Text(
      _formatElapsed(seconds),
      style: AppType.mono(t, size: 16, weight: FontWeight.w700),
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

  bool get _canRemoveLastSet => exercise.sets.length > 1;
  bool get _hasMenu => _canRemoveLastSet || canRemoveExercise;

  void _showMenu(BuildContext context, WidgetRef ref) {
    FocusScope.of(context).unfocus();
    AppSheet.actions(
      context: context,
      ref: ref,
      title: exercise.name,
      actions: [
        if (_canRemoveLastSet)
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
    final showRIR =
        ref.watch(workoutSettingsProvider.select((s) => s.showRIR));

    final warmUpSets = exercise.sets.where((s) => s.isWarmUp).length;
    final done = exercise.sets.where(_isSetDone).length;
    final complete = exercise.sets.isNotEmpty && done == exercise.sets.length;

    return AppCard(
      // The set rows' radius is derived from this padding (card radius minus
      // padding), so change the two together.
      padding: const EdgeInsets.fromLTRB(
        _cardPadding,
        AppSpacing.md,
        _cardPadding,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: _SetRow.rowInset),
            child: ConstrainedBox(
              // Same height with or without the menu button, so cards line up.
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.heading(t),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SwapTransitionBox(
                    value: complete,
                    alignment: Alignment.center,
                    child: complete
                        ? Icon(
                            Icons.check_circle_rounded,
                            key: const ValueKey('complete'),
                            size: 18,
                            color: t.success,
                          )
                        : Text(
                            '$done/${exercise.sets.length}',
                            key: const ValueKey('count'),
                            style: AppType.mono(
                              t,
                              size: 13,
                              weight: FontWeight.w600,
                            ).copyWith(color: t.textSecondary),
                          ),
                  ),
                  if (_hasMenu)
                    AppIconButton(
                      icon: Icons.more_horiz_rounded,
                      size: 36,
                      iconSize: 20,
                      filled: false,
                      color: t.textSecondary,
                      onPressed: () => _showMenu(context, ref),
                      tooltip: 'Exercise options',
                    )
                  else
                    const SizedBox(width: AppSpacing.md),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _SetTableHeader(showRIR: showRIR),
          const SizedBox(height: AppSpacing.xxs),
          for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++)
            _buildSetRow(setIndex, warmUpSets),
          // A quiet, full-width row: adding a set is routine, not the call to
          // action — that is Finish, and the check on each row.
          Pressable(
            onTap: onAddSet,
            scale: 0.98,
            haptic: HapticStrength.selection,
            child: Container(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: t.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Add set',
                    style: AppType.secondary(t).copyWith(
                      fontWeight: FontWeight.w600,
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

  /// Horizontal padding inside the card.
  static const double _cardPadding = AppSpacing.md;

  Widget _buildSetRow(int setIndex, int warmUpSets) {
    final set = exercise.sets[setIndex];
    final previous = setIndex == 0 ? null : exercise.sets[setIndex - 1];

    // A little extra air where the warm-ups end is all the grouping the table
    // needs — the "W" in the set column already marks the warm-up rows.
    final startsWorkingSets =
        !set.isWarmUp && previous != null && previous.isWarmUp;

    return Padding(
      padding: EdgeInsets.only(
        top: startsWorkingSets ? AppSpacing.md : AppSpacing.xs,
      ),
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
    );
  }
}

/// The set table's column layout, shared by the header, the input row and
/// the progression line so every column lines up exactly.
class _SetGrid extends StatelessWidget {
  final Widget badge;
  final Widget weight;
  final Widget reps;
  final Widget? rir;
  final Widget check;

  const _SetGrid({
    required this.badge,
    required this.weight,
    required this.reps,
    required this.rir,
    required this.check,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: _SetRow.badgeWidth, child: badge),
        const SizedBox(width: AppSpacing.sm),
        Expanded(flex: 3, child: weight),
        const SizedBox(width: AppSpacing.sm),
        Expanded(flex: 3, child: reps),
        if (rir != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(flex: 2, child: rir!),
        ],
        const SizedBox(width: AppSpacing.sm),
        SizedBox(width: _SetRow.checkWidth, child: check),
      ],
    );
  }
}

/// Column labels for the set table.
class _SetTableHeader extends ConsumerWidget {
  final bool showRIR;

  const _SetTableHeader({required this.showRIR});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    // Legible at a glance, but quieter than anything in the rows below.
    final style = AppType.overline(t).copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: _hintTone(t),
      letterSpacing: 1.0,
    );

    Widget label(String text) =>
        Text(text, style: style, textAlign: TextAlign.center);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _SetRow.rowInset),
      child: _SetGrid(
        badge: label('SET'),
        weight: label('KG'),
        reps: label('REPS'),
        rir: showRIR ? label('RIR') : null,
        check: const SizedBox.shrink(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Set row
// ---------------------------------------------------------------------------

/// One logged set.
///
/// Interactions:
///  * swipe left/right to copy last session's values into the row,
///  * the check fills every empty field from the grey hints ("as shown"),
///  * per-field edited tracking (typing marks, clearing unmarks),
///  * progression vs the previous session,
///  * per-set menu on the set number: fill, add note, clear, remove.
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

  static const double badgeWidth = 32;
  static const double checkWidth = 44;

  /// Height of the set number and check targets; the inputs size themselves
  /// to the same height through their content padding. Every row is exactly
  /// this plus [rowPadding] on both sides — progression lives inside the
  /// input wells, so a row with a delta is as tall as one without.
  static const double controlHeight = 48;

  /// Padding of the row's tinted band around its controls.
  static const double rowPadding = AppSpacing.xs;

  /// How far the controls sit from the row's edge — the header and the note
  /// use it to line up with them. The swipe outline is painted over the row
  /// (a foreground decoration), so it does not inset anything.
  static const double rowInset = rowPadding;

  /// The row's band, concentric with the card around it.
  static const double rowRadius =
      AppRadius.card - _ExerciseCard._cardPadding;

  /// Input wells and the check tile, concentric with the row's band.
  static const double wellRadius = rowRadius - rowPadding;

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

  /// The user picked "Add note" for a set that had no note to show.
  bool _noteRequested = false;
  final FocusNode _noteFocus = FocusNode();

  /// Whether the set counted as logged for the rest timer on the last update
  /// — see [_isLoggedForRest].
  late bool _loggedForRest;

  /// The reps controller seen on the last update. The screen replaces every
  /// controller when the session's structure changes, so a new instance means
  /// this row may now be showing a different set (one above it was removed)
  /// and a change in [_loggedForRest] is not the user logging anything.
  TextEditingController? _repsControllerSeen;

  /// Set once this row's set has started a rest. Correcting the reps later
  /// (backspace, retype) passes through "not logged" again and must not
  /// restart a rest that is already counting for a later set.
  bool _restStarted = false;

  @override
  void initState() {
    super.initState();
    _loggedForRest = _isLoggedForRest();
    _restStarted = _loggedForRest;
    _repsControllerSeen = _controller(_keys.reps);
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    final repsController = _controller(_keys.reps);
    final structureChanged = !identical(repsController, _repsControllerSeen);
    _repsControllerSeen = repsController;

    final logged = _isLoggedForRest();
    // After a structural change this row may hold a different set; one that
    // is already logged has had its rest.
    if (structureChanged) _restStarted = logged;
    final justLogged =
        logged && !_loggedForRest && !structureChanged && !_restStarted;
    _loggedForRest = logged;
    if (justLogged) _restStarted = true;

    // A set being logged is the moment the rest starts.
    //
    // didUpdateWidget runs inside the build phase and Riverpod rejects provider
    // writes there, so the rest is started once this frame has been laid out.
    if (justLogged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Switched off in Settings: no rest running out of sight (and no
        // target buzz from a timer the user cannot see).
        if (!ref.read(workoutSettingsProvider).showRestTimer) return;
        ref.read(restTimerProvider.notifier).onSetCompleted();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  _SetKeys get _keys => _SetKeys(widget.exerciseName, widget.setIndex);

  WorkoutStateNotifier get _notifier => ref.read(workoutProvider.notifier);

  TextEditingController? _controller(String key) => widget.controllers[key];

  /// Logged, for the rest timer, means done *and* the reps came from the user
  /// — typed, or copied from last session with the check or a swipe. Typing
  /// only the weight also makes a set done (the provider takes last session's
  /// reps for the empty field), but people do that *before* the set, so it
  /// must not start the rest. Warm-ups never do: nobody rests two minutes
  /// after an empty bar.
  bool _isLoggedForRest() {
    final set = widget.set;
    if (set.isWarmUp || !_isSetDone(set)) return false;
    return ref.read(workoutProvider).editedFields.contains(_keys.reps);
  }

  // --- placeholders -----------------------------------------------------

  static bool _isHint(Object? value) =>
      (value is num && value > 0) || (value is String && value.isNotEmpty);

  bool _hasPlaceholders(Map<String, dynamic> placeholders) {
    final keys = _keys;
    return _isHint(placeholders[keys.weight]) ||
        _isHint(placeholders[keys.reps]) ||
        _isHint(placeholders[keys.notes]) ||
        _isHint(placeholders[keys.rir]);
  }

  /// Copies the previous session's values into this row. With [onlyEmpty]
  /// anything the user already typed is kept and only the fields still showing
  /// a hint are filled — that is what the check does. The swipe and the menu
  /// overwrite the whole row.
  void _fillFromLastSession({bool onlyEmpty = false}) {
    final placeholders = ref.read(workoutProvider).placeholders;
    final keys = _keys;

    bool canFill(String key) =>
        _isHint(placeholders[key]) &&
        (!onlyEmpty || (_controller(key)?.text ?? '').isEmpty);

    double? weight;
    int? reps;
    String? notes;
    int? rir;
    final editedKeys = <String>[];

    if (canFill(keys.weight)) {
      weight = (placeholders[keys.weight] as num).toDouble();
      _controller(keys.weight)?.text = AppFormat.weight(weight);
      editedKeys.add(keys.weight);
    }

    if (canFill(keys.reps)) {
      reps = (placeholders[keys.reps] as num).toInt();
      _controller(keys.reps)?.text = reps.toString();
      editedKeys.add(keys.reps);
    }

    if (canFill(keys.notes)) {
      notes = placeholders[keys.notes] as String;
      _controller(keys.notes)?.text = notes;
      editedKeys.add(keys.notes);
    }

    if (canFill(keys.rir)) {
      rir = (placeholders[keys.rir] as num).toInt();
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
    setState(() => _noteRequested = false);
    HapticFeedback.selectionClick();
  }

  void _openNote() {
    setState(() => _noteRequested = true);
    // The field only exists from the next frame on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _noteFocus.requestFocus();
    });
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

  void _showSetMenu({required bool canFill, required bool noteVisible}) {
    FocusScope.of(context).unfocus();

    final label = widget.set.isWarmUp
        ? 'Warm-up ${widget.setIndex + 1}'
        : 'Set ${widget.setIndex - widget.warmUpSets + 1}';

    AppSheet.actions(
      context: context,
      ref: ref,
      // The set as the title, the exercise quietly underneath — a long
      // "Exercise · Set" title outweighed the whole page.
      title: label,
      subtitle: widget.exerciseName,
      actions: [
        if (canFill)
          SheetAction(
            icon: Icons.replay_rounded,
            label: 'Same as last session',
            description: _lastSessionSummary(),
            onTap: _fillFromLastSession,
          ),
        if (!noteVisible)
          SheetAction(
            icon: Icons.sticky_note_2_outlined,
            label: 'Add note',
            onTap: _openNote,
          ),
        SheetAction(
          icon: Icons.backspace_outlined,
          label: 'Clear set',
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

  /// "80 kg × 8 reps" — what "Same as last session" would fill in.
  String? _lastSessionSummary() {
    final placeholders = ref.read(workoutProvider).placeholders;
    final weight = placeholders[_keys.weight];
    final reps = placeholders[_keys.reps];
    final parts = [
      if (weight is num && weight > 0) '${AppFormat.weight(weight)} kg',
      if (reps is num && reps > 0) '$reps ${reps == 1 ? 'rep' : 'reps'}',
    ];
    return parts.isEmpty ? null : parts.join(' × ');
  }

  // --- inputs -----------------------------------------------------------

  static double _parseWeight(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.')) ?? 0.0;

  static int _parseInt(String text) => int.tryParse(text.trim()) ?? 0;

  // Weight and reps are always sent as a pair, but only a *typed* partner is
  // passed on: an empty partner field goes through as 0, and the provider
  // decides whether last session's hint stands in for it.

  void _onWeightChanged(String value) {
    final keys = _keys;
    if (value.isEmpty) {
      _notifier.unmarkFieldEdited(keys.weight);
    } else {
      _notifier.markFieldEdited(keys.weight);
    }
    _notifier.updateSetData(
      widget.exerciseIndex,
      widget.setIndex,
      weight: _parseWeight(value),
      reps: _parseInt(_controller(keys.reps)?.text ?? ''),
    );
  }

  void _onRepsChanged(String value) {
    final keys = _keys;
    if (value.isEmpty) {
      _notifier.unmarkFieldEdited(keys.reps);
    } else {
      _notifier.markFieldEdited(keys.reps);
    }
    _notifier.updateSetData(
      widget.exerciseIndex,
      widget.setIndex,
      weight: _parseWeight(_controller(keys.weight)?.text ?? ''),
      reps: _parseInt(value),
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
      rir: _parseInt(value),
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
    final complete = _isSetDone(set);
    final hasPlaceholders = _hasPlaceholders(placeholders);
    final canFill = hasPlaceholders && !complete;

    // The check can log the row "as shown" while the weight or reps field is
    // still showing last session's grey hint.
    bool showsHint(String key) =>
        !edited.contains(key) && _isHint(placeholders[key]);
    final canLogAsShown = showsHint(keys.weight) || showsHint(keys.reps);

    final noteVisible = _noteRequested ||
        (set.notes?.isNotEmpty ?? false) ||
        edited.contains(keys.notes) ||
        _isHint(placeholders[keys.notes]);

    final progression = settings.showProgression
        ? _visibleProgression(edited, placeholders)
        : const _Progression(null, null);

    // Done sets settle: the input wells drop away so the numbers sit straight
    // on the row, and a working set gets a faint success band. Warm-ups get
    // no band at all — they are the least important rows on the screen.
    final washed = complete && !isWarmUp;
    final numberStyle = AppType.mono(t, size: 19, weight: FontWeight.w700);

    final weightDelta = progression.weight;
    final repsDelta = progression.reps;

    final inputs = _SetGrid(
      badge: _SetBadge(
        label: isWarmUp ? 'W' : '${widget.setIndex - widget.warmUpSets + 1}',
        color: isWarmUp ? t.warning : t.textSecondary,
        onTap: () =>
            _showSetMenu(canFill: canFill, noteVisible: noteVisible),
      ),
      weight: _ValueField(
        theme: t,
        controller: _controller(keys.weight),
        hintText: _placeholderText(placeholders, keys.weight),
        edited: edited.contains(keys.weight),
        filled: !complete,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: numberStyle,
        onChanged: _onWeightChanged,
        delta: weightDelta != null && weightDelta != 0
            ? _DeltaMark(theme: t, delta: weightDelta, unit: 'kg')
            : null,
      ),
      reps: _ValueField(
        theme: t,
        controller: _controller(keys.reps),
        hintText: _placeholderText(placeholders, keys.reps),
        edited: edited.contains(keys.reps),
        filled: !complete,
        keyboardType: TextInputType.number,
        style: numberStyle,
        onChanged: _onRepsChanged,
        delta: repsDelta != null && repsDelta != 0
            ? _DeltaMark(
                theme: t,
                delta: repsDelta,
                unit: repsDelta.abs() == 1 ? 'rep' : 'reps',
              )
            : null,
      ),
      rir: settings.showRIR
          ? _ValueField(
              theme: t,
              controller: _controller(keys.rir),
              hintText: _placeholderText(placeholders, keys.rir),
              edited: edited.contains(keys.rir),
              filled: !complete,
              keyboardType: TextInputType.number,
              style: numberStyle.copyWith(fontSize: 17),
              onChanged: _onRirChanged,
            )
          : null,
      check: Center(
        child: _SetCheck(
          state: complete
              ? (isWarmUp ? _CheckState.warmUpDone : _CheckState.done)
              : (canLogAsShown ? _CheckState.ready : _CheckState.idle),
          onTap: canLogAsShown
              ? () => _fillFromLastSession(onlyEmpty: true)
              : null,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _offsetAnimation,
          builder: (context, child) {
            final offset = _animationController.isAnimating
                ? _offsetAnimation.value
                : _swipeOffset;
            final swipeProgress = (offset.abs() / _maxSwipe).clamp(0.0, 1.0);
            final active = hasPlaceholders && swipeProgress > 0.05;

            // Fully transparent at rest, so an untouched row is just its
            // inputs on the card. Faintly banded once a working set is done;
            // the swipe (an action) tints toward the accent as it travels.
            final restingColor =
                washed ? _doneWash(t) : t.success.withValues(alpha: 0);
            final background = active
                ? Color.lerp(restingColor, t.primaryWash, swipeProgress)!
                : restingColor;
            final borderColor = active
                ? t.primary.withValues(
                    alpha: (swipeProgress * 0.6).clamp(0.0, 1.0),
                  )
                : t.primary.withValues(alpha: 0);
            final radius = BorderRadius.circular(_SetRow.rowRadius);

            return Transform.translate(
              offset: Offset(offset, 0),
              child: GestureDetector(
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  padding: const EdgeInsets.all(_SetRow.rowPadding),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: radius,
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: borderColor),
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: inputs,
        ),
        if (noteVisible)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _SetRow.rowInset + _SetRow.badgeWidth + AppSpacing.sm,
              AppSpacing.xs,
              _SetRow.rowInset,
              AppSpacing.xxs,
            ),
            child: _NoteField(
              theme: t,
              controller: _controller(keys.notes),
              focusNode: _noteFocus,
              hintText: _placeholderText(placeholders, keys.notes),
              edited: edited.contains(keys.notes),
              onChanged: _onNotesChanged,
            ),
          ),
      ],
    );
  }

  /// Progression is hidden for warm-ups, for rows the user has not touched yet
  /// and for rows that are still completely empty.
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
    if (_isSetEmpty(set)) return const _Progression(null, null);

    return _progressionFor(
      set: set,
      exerciseName: widget.exerciseName,
      setIndex: widget.setIndex,
      placeholders: placeholders,
    );
  }
}

/// The set number ("W" for warm-ups). Tapping opens the per-set menu.
class _SetBadge extends ConsumerWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SetBadge({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Tooltip(
      message: 'Set options',
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        haptic: HapticStrength.selection,
        child: SizedBox(
          height: _SetRow.controlHeight,
          child: Center(
            child: Text(
              label,
              style: AppType.mono(t, size: 15, weight: FontWeight.w700)
                  .copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

enum _CheckState {
  /// Nothing logged and nothing for the check to fill in.
  idle,

  /// Still showing last session's hints — the check logs them as shown.
  ready,

  /// A working set with reps.
  done,

  /// A warm-up with reps.
  warmUpDone,
}

/// Completion affordance. Neutral until the set is done: an outline with a
/// faint tick, a slightly stronger tick while tapping it would log the grey
/// hints as they are. Done is the success tone — a soft tile for working
/// sets, just a muted tick for warm-ups — never a solid block, so the numbers
/// beside it stay the loudest thing on the row.
class _SetCheck extends ConsumerWidget {
  final _CheckState state;
  final VoidCallback? onTap;

  const _SetCheck({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final (Color fill, Color outline, Color tick) = switch (state) {
      _CheckState.idle => (
          t.surface.withValues(alpha: 0),
          t.outline,
          _hintTone(t),
        ),
      _CheckState.ready => (
          t.surface.withValues(alpha: 0),
          t.outline,
          t.textSecondary,
        ),
      _CheckState.done => (
          t.successWash,
          t.success.withValues(alpha: 0),
          t.success,
        ),
      _CheckState.warmUpDone => (
          t.success.withValues(alpha: 0),
          t.success.withValues(alpha: 0),
          t.success.withValues(alpha: 0.72),
        ),
    };

    return Pressable(
      onTap: onTap,
      scale: 0.88,
      // The fill fires its own haptic — only when it actually changes the row.
      haptic: HapticStrength.none,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        width: _SetRow.checkWidth,
        height: _SetRow.controlHeight,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(_SetRow.wellRadius),
          border: Border.all(color: outline, width: 1.2),
        ),
        child: Icon(Icons.check_rounded, size: 22, color: tick),
      ),
    );
  }
}

/// A big, centred numeric input. Text is full-contrast once the user has
/// edited the field; last session's hint is a lighter weight in a quieter (but
/// still readable) tone. Once the set is done the well itself drops away
/// ([filled] off) and the value sits straight on the row.
class _ValueField extends StatelessWidget {
  final AppColors theme;
  final TextEditingController? controller;
  final String hintText;
  final bool edited;
  final bool filled;
  final TextInputType keyboardType;
  final TextStyle style;
  final ValueChanged<String> onChanged;

  /// Change vs last session, set as a superscript on the value inside the
  /// well, so a row with a delta is exactly as tall as one without.
  final _DeltaMark? delta;

  const _ValueField({
    required this.theme,
    required this.controller,
    required this.hintText,
    required this.edited,
    required this.filled,
    required this.keyboardType,
    required this.style,
    required this.onChanged,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final radius = BorderRadius.circular(_SetRow.wellRadius);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );
    final hintStyle = style.copyWith(
      color: _hintTone(t),
      fontWeight: FontWeight.w500,
    );

    final field = TextField(
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
        filled: filled,
        fillColor: t.surface,
        hintText: hintText.isEmpty ? null : hintText,
        hintStyle: hintStyle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: t.primary, width: 1.6),
        ),
      ),
    );

    // The delta reads as a superscript on the value: just past the number's
    // right edge, its top level with the digits'. The number is centred, so
    // that edge moves with what the field shows — typed text, else the hint.
    // Measured against the same base style the field resolves its text from.
    final themeData = Theme.of(context);
    final inputBase = (themeData.useMaterial3
            ? themeData.textTheme.bodyLarge
            : themeData.textTheme.titleMedium) ??
        const TextStyle();
    final scaler = MediaQuery.textScalerOf(context);
    double widthOf(String text, TextStyle textStyle) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: inputBase.merge(textStyle)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // The same tree with or without a delta: a delta appears the moment a
    // typed value differs from last time, and swapping the field's parent
    // then would remount it — dropping focus and the keyboard mid-entry.
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget layer(TextEditingValue? value) {
          final mark = delta;
          Widget? superscript;
          if (mark != null) {
            final typed = value != null && value.text.isNotEmpty;
            final numberWidth = widthOf(
              typed ? value.text : hintText,
              typed ? style : hintStyle,
            );
            final markWidth =
                widthOf(mark.text, _DeltaMark.styleFor(t, mark.delta));
            final cell = constraints.maxWidth;
            superscript = Positioned(
              left: math.min(
                cell / 2 + numberWidth / 2 + AppSpacing.xxs,
                math.max(0.0, cell - markWidth - AppSpacing.xs),
              ),
              top: _DeltaMark.top,
              child: IgnorePointer(child: mark),
            );
          }
          return Stack(
            children: [field, if (superscript != null) superscript],
          );
        }

        final values = controller;
        if (values == null) return layer(null);
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: values,
          builder: (context, value, _) => layer(value),
        );
      },
    );
  }
}

/// "+2.5" / "−1" in the success or error tone — the progression vs last
/// session, set as a superscript on the value it belongs to. The column
/// header already names the unit, so it is only spoken, not printed.
class _DeltaMark extends StatelessWidget {
  final AppColors theme;
  final num delta;
  final String unit;

  const _DeltaMark({
    required this.theme,
    required this.delta,
    required this.unit,
  });

  /// Offset from the well's top that levels the mark's top with the digits
  /// of the centred 19pt value.
  static const double top = 13;

  static TextStyle styleFor(AppColors t, num delta) =>
      AppType.mono(t, size: 10.5, weight: FontWeight.w700).copyWith(
        color: t.deltaColor(delta),
        height: 1,
      );

  String get text => AppFormat.delta(delta);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${AppFormat.delta(delta, unit: unit)} since last session',
      excludeSemantics: true,
      child: Text(text, style: styleFor(theme, delta)),
    );
  }
}

/// The free-text note under a set. Only shown when there is something to
/// show or the user asked for it. Grows as it is typed into.
class _NoteField extends StatelessWidget {
  final AppColors theme;
  final TextEditingController? controller;
  final FocusNode focusNode;
  final String hintText;
  final bool edited;
  final ValueChanged<String> onChanged;

  const _NoteField({
    required this.theme,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.edited,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final radius = BorderRadius.circular(_SetRow.wellRadius);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
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
        fillColor: t.surface,
        prefixIcon: Icon(
          Icons.sticky_note_2_outlined,
          size: 15,
          color: _hintTone(t),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        hintText: hintText.isEmpty ? 'Note' : hintText,
        hintStyle: AppType.secondary(t).copyWith(
          fontSize: 13.5,
          color: _hintTone(t),
        ),
        contentPadding: const EdgeInsets.only(
          right: AppSpacing.md,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: t.primary, width: 1.6),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Completion dialog content
// ---------------------------------------------------------------------------

class _CompletionContent extends ConsumerWidget {
  final int minutes;
  final _WorkoutSummary summary;
  final SessionComparison comparison;

  const _CompletionContent({
    required this.minutes,
    required this.summary,
    required this.comparison,
  });

  static const int _maxRows = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md + AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: t.surface,
            // Matches the Done button below it.
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: t.outline),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.timer_outlined,
                    label: 'Time',
                    value: AppFormat.duration(minutes),
                  ),
                ),
                VerticalDivider(
                  width: AppSpacing.xxl,
                  thickness: 1,
                  color: t.divider,
                ),
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.checklist_rounded,
                    label: 'Working sets',
                    value: '${summary.completedWorkingSets}',
                    delta: comparison.setDelta,
                    deltaUnit: (comparison.setDelta ?? 0).abs() == 1
                        ? 'set'
                        : 'sets',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (comparison.exercises.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          WorkoutComparisonList(comparison: comparison, maxRows: _maxRows),
        ],
      ],
    );
  }
}

class _MiniMetric extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Change against last time, shown beside the value with its sign.
  final num? delta;
  final String deltaUnit;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.delta,
    this.deltaUnit = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final change = delta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: t.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption(t).copyWith(
                  fontSize: 12,
                  color: t.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.metric(t, size: 22),
              ),
            ),
            if (change != null && change != 0) ...[
              const SizedBox(width: AppSpacing.sm),
              DeltaBadge(
                delta: change,
                unit: deltaUnit,
                compact: true,
                fontSize: 11.5,
              ),
            ],
          ],
        ),
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
            hint: 'Tracked for progress',
            value: _workingSets,
            min: 1,
            max: 15,
            onChanged: (value) => setState(() => _workingSets = value),
          ),
          Divider(height: AppSpacing.xxl, color: t.divider),
          _CountStepper(
            label: 'Warm-up sets',
            hint: 'Not tracked for progress',
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
              const SizedBox(height: AppSpacing.xxs),
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

  /// When it was left and what is in it — what the choice depends on.
  static String _staleMessage(WorkoutSession session) {
    final summary = _WorkoutSummary.of(session);
    final when = AppFormat.relativeDate(session.date).toLowerCase();
    final logged = summary.completedSets == 0
        ? 'with nothing logged yet'
        : 'with ${summary.completedSets} of ${summary.totalSets} sets logged';
    return 'Left running $when, $logged. '
        'Pick up where you left off, or discard it.';
  }

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
                                // Neutral: nothing is wrong, and warning
                                // is the warm-up marker on this screen.
                                IconBadge(
                                  icon: Icons.history_rounded,
                                  color: t.textSecondary,
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
                                      const SizedBox(height: AppSpacing.xxs),
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
                              _staleMessage(staleSession),
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
