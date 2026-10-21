import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise_model.dart';
import '../models/master_exercise_model.dart';
import '../models/standard_workout_template.dart';
import '../models/workout_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/exercise_list_item.dart';
import '../widgets/ui/ui.dart';
import 'choose_category_screen.dart';
import 'template_detail_page.dart';

/// The workout builder.
///
/// Three ways in share this screen:
///   * **tab** — the "Create" tab of `MainScreen`. Shows a Build/Templates
///     switcher and reports back through [onWorkoutSaved].
///   * **pushed create** — the same builder pushed as a route (no callback).
///   * **edit** — pushed with [workoutToEdit]. Templates are hidden and saving
///     updates the existing program in place, keeping its id.
class CreateWorkoutScreen extends ConsumerStatefulWidget {
  /// Called with the tab index to show after a successful save (0 = Home).
  final Function(int)? onWorkoutSaved;

  /// When set, the screen edits this program instead of creating a new one.
  final WorkoutProgram? workoutToEdit;

  const CreateWorkoutScreen({super.key, this.onWorkoutSaved, this.workoutToEdit});

  @override
  ConsumerState<CreateWorkoutScreen> createState() =>
      _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends ConsumerState<CreateWorkoutScreen> {
  static const int _tabBuild = 0;
  static const int _tabTemplates = 1;

  /// Working sets a newly added exercise starts with. Matches the default of
  /// the active workout's "Add exercise" sheet, and saves two taps per row for
  /// the most common program shape.
  static const int _defaultWorkingSets = 3;

  /// How long the "removed — Undo" snack stays up.
  static const Duration _undoWindow = Duration(seconds: 4);

  /// Vertical room the floating save bar needs: the large button plus the gap
  /// above it. Only reserved while the bar is actually on screen.
  static const double _saveBarExtent = 58 + AppSpacing.lg;

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  List<Exercise> _exercises = <Exercise>[];
  late Stream<List<StandardWorkoutTemplate>> _templateStream;

  /// The user's existing programs — for the duplicate-name check and to mark
  /// templates that are already copied.
  StreamSubscription<List<WorkoutProgram>>? _programsSub;
  List<WorkoutProgram> _programs = const <WorkoutProgram>[];

  /// The form as it was opened (or last saved), to tell whether leaving the
  /// screen would throw work away.
  String _savedSignature = '';

  bool _isLoading = false;
  bool _isReordering = false;

  /// Set by a save attempt with an empty name, so the field only nags after
  /// the user actually tried.
  bool _showNameRequired = false;

  int _tab = _tabBuild;

  bool get _isEditMode => widget.workoutToEdit != null;

  /// Hosted as a tab of `MainScreen` (floating nav bar underneath, no back).
  bool get _isTab => !_isEditMode && widget.onWorkoutSaved != null;

  bool get _isDirty => _signature() != _savedSignature;

  /// The save bar rides in once there is something to save — and stays put
  /// while the save is in flight, so it does not slide away mid-spinner.
  bool get _showSaveBar => _exercises.isNotEmpty || _isEditMode || _isLoading;

  int get _workingSets =>
      _exercises.fold<int>(0, (sum, exercise) => sum + exercise.workingSets);

  int get _warmUpSets =>
      _exercises.fold<int>(0, (sum, exercise) => sum + exercise.warmUpSets);

  @override
  void initState() {
    super.initState();

    // Edit mode: prefill from the program being edited. The exercises are
    // copied, not shared — the sets sheet mutates them in place, and backing
    // out without saving must leave the caller's program untouched.
    final program = widget.workoutToEdit;
    if (program != null) {
      _nameController.text = program.title;
      _exercises = program.exercises
          .map((e) => Exercise(
                id: e.id,
                name: e.name,
                sets: e.sets,
                workingSets: e.workingSets,
                warmUpSets: e.warmUpSets,
              ))
          .toList();
    }
    _savedSignature = _signature();

    _nameController.addListener(_onNameChanged);
    _templateStream = StandardWorkoutService.getStandardWorkouts();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _programsSub = DatabaseService(uid: user.uid).getWorkoutPrograms().listen(
        (programs) {
          if (mounted) setState(() => _programs = programs);
        },
        // Only powers a convenience check — never worth surfacing.
        onError: (Object _) {},
      );
    }
  }

  @override
  void dispose() {
    _programsSub?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!mounted) return;
    setState(() {
      if (_nameController.text.trim().isNotEmpty) _showNameRequired = false;
    });
  }

  String _signature() => <String>[
        _nameController.text.trim(),
        for (final e in _exercises) '${e.id}:${e.workingSets}:${e.warmUpSets}',
      ].join('|');

  static String _key(String s) => s.trim().toLowerCase();

  /// Program titles key the "last time" values in the active workout, so two
  /// programs with the same name would share (and muddle) their history.
  bool _isTakenName(String title) {
    final key = _key(title);
    if (key.isEmpty) return false;
    // Keeping the current name while editing is always fine.
    final original = widget.workoutToEdit;
    if (original != null && _key(original.title) == key) return false;
    return _programs.any((p) => p.id != original?.id && _key(p.title) == key);
  }

  String? get _nameError {
    final name = _nameController.text;
    if (name.trim().isEmpty) {
      return _showNameRequired ? 'Name your workout' : null;
    }
    if (_isTakenName(name)) return 'You already have a workout with this name';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Exercises
  // ---------------------------------------------------------------------------

  Future<void> _navigateAndAddExercise() async {
    FocusScope.of(context).unfocus();

    // ChooseCategoryScreen returns a MasterExercise (the library entry) — or
    // null when the user backs out.
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) => const ChooseCategoryScreen(),
      ),
    );

    if (!mounted || result is! MasterExercise) return;

    // The active workout keys "last time" values by exercise name, so a
    // repeat is allowed but should be deliberate rather than a double tap.
    final isRepeat = _exercises.any((e) => _key(e.name) == _key(result.name));
    if (isRepeat) {
      final addAgain = await AppDialog.confirm(
        context: context,
        ref: ref,
        title: 'Already in this workout',
        message: 'Add ${result.name} a second time?',
        confirmLabel: 'Add again',
      );
      if (!addAgain || !mounted) return;
    }

    // The library entry becomes a fresh instance in *this* workout, with its
    // own id so a repeated movement still has a stable identity.
    setState(() {
      _exercises.add(
        Exercise(
          id: const Uuid().v4(),
          name: result.name,
          sets: _defaultWorkingSets,
          workingSets: _defaultWorkingSets,
          warmUpSets: 0,
        ),
      );
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      // Moving an item down shifts the indices differently than moving it up.
      if (oldIndex < newIndex) newIndex -= 1;
      final Exercise item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
  }

  Future<void> _showExerciseOptions(Exercise exercise) async {
    FocusScope.of(context).unfocus();

    await AppSheet.show<void>(
      context: context,
      ref: ref,
      title: exercise.name,
      builder: (sheetContext) => _EditSetsSheet(
        workingSets: exercise.workingSets,
        warmUpSets: exercise.warmUpSets,
        onChanged: (working, warmUp) => _applySets(exercise, working, warmUp),
        onRemove: () {
          Navigator.of(sheetContext).pop();
          _removeExercise(exercise);
        },
      ),
    );
  }

  void _applySets(Exercise exercise, int workingSets, int warmUpSets) {
    setState(() {
      exercise.workingSets = workingSets;
      exercise.warmUpSets = warmUpSets;
      exercise.sets = workingSets + warmUpSets;
    });
  }

  /// Removes straight away and offers Undo — nothing is persisted until the
  /// workout is saved, so a confirmation dialog would only add friction.
  void _removeExercise(Exercise exercise) {
    final index = _exercises.indexWhere((e) => e.id == exercise.id);
    if (index < 0) return;

    setState(() {
      _exercises.removeAt(index);
      if (_exercises.length < 2) _isReordering = false;
    });

    final t = ref.read(themeProvider);
    AppSnack.show(
      context,
      ref,
      '${exercise.name} removed',
      duration: _undoWindow,
      action: SnackBarAction(
        label: 'Undo',
        textColor: t.primary,
        onPressed: () {
          if (!mounted || _exercises.any((e) => e.id == exercise.id)) return;
          setState(() {
            _exercises.insert(index.clamp(0, _exercises.length), exercise);
          });
        },
      ),
    );
  }

  void _toggleReordering() {
    FocusScope.of(context).unfocus();
    setState(() => _isReordering = !_isReordering);
  }

  // ---------------------------------------------------------------------------
  // Saving and leaving
  // ---------------------------------------------------------------------------

  Future<void> _saveWorkout() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final title = _nameController.text.trim();

    if (title.isEmpty) {
      setState(() => _showNameRequired = true);
      _nameFocus.requestFocus();
      return;
    }
    if (_isTakenName(title)) {
      _nameFocus.requestFocus();
      return;
    }
    if (_exercises.isEmpty) {
      AppSnack.show(context, ref, 'Add at least one exercise', isError: true);
      return;
    }

    // Editing without changes: nothing to write.
    if (_isEditMode && !_isDirty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in!');
      }
      final db = DatabaseService(uid: user.uid);

      if (widget.workoutToEdit != null) {
        // UPDATE — keep the existing document id.
        await db.updateWorkoutProgram(
          WorkoutProgram(
            id: widget.workoutToEdit!.id,
            title: title,
            exercises: _exercises,
          ),
        );
      } else {
        // CREATE — mint a new id.
        await db.saveWorkoutProgram(
          WorkoutProgram(
            id: const Uuid().v4(),
            title: title,
            exercises: _exercises,
          ),
        );
      }

      if (!mounted) return;

      AppSnack.show(
        context,
        ref,
        _isEditMode ? 'Workout updated' : 'Workout saved',
      );

      if (_isTab) {
        // The tab stays alive, so clear it for the next program and hand
        // control back to the shell.
        _nameController.clear();
        setState(() {
          _exercises = <Exercise>[];
          _isReordering = false;
          _showNameRequired = false;
          _savedSignature = _signature();
        });
        widget.onWorkoutSaved!(0); // 0 = Home tab
      } else {
        _savedSignature = _signature();
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Could not save the workout: $e');
      if (mounted) {
        AppSnack.show(context, ref, 'Could not save the workout. Try again.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDiscard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final discard = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Discard changes?',
      message: _isEditMode
          ? 'Your edits to this workout will be lost.'
          : 'This workout has not been saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final showBuilder = _isEditMode || _tab == _tabBuild;

    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;

    // As a tab the floating nav bar overlays the bottom of the screen, so the
    // sticky save bar has to clear it. Pushed as a route there is no bar.
    // `AppSpacing.md` of air keeps the button from sitting kerb-to-kerb on the
    // nav bar — they should read as two separate things, not one tall slab.
    final double navClearance = _isTab ? NavBarMetrics.totalHeight : 0;
    final double barBottom = keyboard > 0
        ? keyboard + AppSpacing.sm
        : media.padding.bottom + navClearance + AppSpacing.md;

    final double baseBottom =
        _isTab ? AppSpacing.navBarClearance : AppSpacing.xxl;

    // The bar floats over the content, so the list has to end above it — but
    // only while it is showing, otherwise the screen carries dead space.
    final double builderBottomPadding =
        baseBottom + (_showSaveBar ? _saveBarExtent : 0);

    final screen = Stack(
      fit: StackFit.expand,
      children: [
        AppScaffold(
          title: _isEditMode ? 'Edit workout' : 'Create workout',
          bottomPadding: showBuilder ? builderBottomPadding : baseBottom,
          headerBottom: _isEditMode
              ? null
              : AppSegmented<int>(
                  value: _tab,
                  segments: const <AppSegment<int>>[
                    AppSegment(value: _tabBuild, label: 'Build'),
                    AppSegment(value: _tabTemplates, label: 'Templates'),
                  ],
                  onChanged: (value) {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _tab = value;
                      _isReordering = false;
                    });
                  },
                ),
          slivers: showBuilder ? _builderSlivers(t) : _templateSlivers(),
        ),

        // Sticky save bar — floats over the content, above the nav bar, and
        // only once there is something to save.
        if (showBuilder)
          Positioned(
            left: 0,
            right: 0,
            bottom: barBottom,
            child: Material(
              type: MaterialType.transparency,
              child: _SaveBar(
                label: _isEditMode ? 'Save changes' : 'Save workout',
                visible: _showSaveBar,
                loading: _isLoading,
                onPressed: _isLoading ? null : _saveWorkout,
              ),
            ),
          ),
      ],
    );

    // A tab has nothing to pop; as a route, leaving with unsaved work asks.
    if (_isTab) return screen;

    return PopScope<Object?>(
      canPop: !_isDirty || _isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: screen,
    );
  }

  // ---------------------------------------------------------------------------
  // Builder tab
  // ---------------------------------------------------------------------------

  String? get _setsSummary {
    if (_exercises.isEmpty) return null;
    final working = _workingSets;
    final warmUp = _warmUpSets;
    final base = '$working working ${working == 1 ? 'set' : 'sets'}';
    return warmUp == 0 ? base : '$base · $warmUp warm-up';
  }

  List<Widget> _builderSlivers(AppColors t) {
    final hasExercises = _exercises.isNotEmpty;

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: FadeSlideIn(
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              style: AppType.heading(t),
              decoration: InputDecoration(
                hintText: 'Workout name',
                counterText: '',
                errorText: _nameError,
              ),
              onSubmitted: (_) => _nameFocus.unfocus(),
            ),
          ),
        ),
      ),
      // The "Exercises" header only earns its place once there is a list
      // under it; the empty guide explains itself.
      if (hasExercises)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xxl,
            AppSpacing.screenH,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    title: 'Exercises',
                    subtitle: _setsSummary,
                    padding: EdgeInsets.zero,
                  ),
                ),
                // The toggle sits with the list it rearranges.
                if (_exercises.length > 1)
                  AppButton.ghost(
                    label: _isReordering ? 'Done' : 'Reorder',
                    icon: _isReordering
                        ? Icons.check_rounded
                        : Icons.swap_vert_rounded,
                    size: AppButtonSize.small,
                    onPressed: _toggleReordering,
                  ),
              ],
            ),
          ),
        ),
      if (hasExercises)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          sliver: SliverReorderableList(
            itemCount: _exercises.length,
            // `onReorder` is deprecated in favour of `onReorderItem` as of
            // Flutter 3.41, but `onReorderItem` does not exist on 3.29, which
            // this project's SDK constraint still allows. Keep this until the
            // pubspec floor moves; `_onReorder` already does the index
            // adjustment the newer callback would do for us.
            // ignore: deprecated_member_use
            onReorder: _onReorder,
            proxyDecorator: _dragProxy,
            itemBuilder: (context, index) {
              final exercise = _exercises[index];
              final row = ExerciseListItem(
                exercise: exercise,
                isReordering: _isReordering,
                onMenuPressed: () => _showExerciseOptions(exercise),
              );

              return KeyedSubtree(
                key: ValueKey<String>(exercise.id),
                child: FadeSlideIn(
                  index: index,
                  child: _isReordering
                      // Explicit reorder mode: grab anywhere on the row.
                      ? ReorderableDragStartListener(index: index, child: row)
                      // Otherwise reordering stays available on a long press.
                      : ReorderableDelayedDragStartListener(
                          index: index,
                          child: row,
                        ),
                ),
              );
            },
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          hasExercises ? AppSpacing.xxs : AppSpacing.lg,
          AppSpacing.screenH,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: FadeSlideIn(
            // Empty: a short guide that ends in the one accented action.
            // Filled: the next slot in the list, so Save is the only primary.
            child: hasExercises
                ? _AddExerciseRow(onTap: _navigateAndAddExercise)
                : _BuildGuide(
                    named: _nameController.text.trim().isNotEmpty,
                    onAddExercise: _navigateAndAddExercise,
                    onBrowseTemplates: _isEditMode
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            setState(() => _tab = _tabTemplates);
                          },
                  ),
          ),
        ),
      ),
    ];
  }

  /// Lifts the dragged row off the page while it is being moved.
  Widget _dragProxy(Widget child, int index, Animation<double> animation) {
    final t = ref.read(themeProvider);

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, inner) {
        final v = Curves.easeOut.transform(animation.value.clamp(0.0, 1.0));
        return Transform.scale(
          scale: 1 + 0.035 * v,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: t.shadowFloating,
            ),
            child: inner,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Templates tab
  // ---------------------------------------------------------------------------

  List<Widget> _templateSlivers() {
    return <Widget>[
      StreamBuilder<List<StandardWorkoutTemplate>>(
        stream: _templateStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    SkeletonCard(height: 132),
                    SizedBox(height: AppSpacing.md),
                    SkeletonCard(height: 132),
                    SizedBox(height: AppSpacing.md),
                    SkeletonCard(height: 132),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorState(
                message: 'Could not load the templates.',
                onRetry: () => setState(() {
                  _templateStream = StandardWorkoutService.getStandardWorkouts();
                }),
              ),
            );
          }

          final templates = snapshot.data ?? const <StandardWorkoutTemplate>[];

          if (templates.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.star_rounded,
                title: 'No templates yet',
                actionLabel: 'Build your own',
                onAction: () => setState(() => _tab = _tabBuild),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final template = templates[index];
                  return FadeSlideIn(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _TemplateCard(
                        template: template,
                        alreadyAdded: isTemplateInPrograms(template, _programs),
                      ),
                    ),
                  );
                },
                childCount: templates.length,
              ),
            ),
          );
        },
      ),
    ];
  }
}

/// ---------------------------------------------------------------------------
/// The empty builder: what the three steps are, then the one way forward —
/// and, for anyone who would rather not start from nothing, the templates.
/// ---------------------------------------------------------------------------
class _BuildGuide extends ConsumerWidget {
  /// Step one is done — it gets a check instead of its number.
  final bool named;

  final VoidCallback onAddExercise;

  /// Null hides the templates hint (edit mode has no templates tab).
  final VoidCallback? onBrowseTemplates;

  const _BuildGuide({
    required this.named,
    required this.onAddExercise,
    required this.onBrowseTemplates,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Three steps to a workout', style: AppType.heading(t)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Set it up once, then start it in one tap.',
                style: AppType.secondary(t),
              ),
              const SizedBox(height: AppSpacing.xl),
              _GuideStep(
                number: 1,
                done: named,
                title: 'Name it',
                detail: 'Like Push Day, Legs or Upper A.',
              ),
              const _GuideStep(
                number: 2,
                title: 'Add exercises',
                detail: 'From your library, or create your own.',
              ),
              const _GuideStep(
                number: 3,
                title: 'Set the sets',
                detail: 'Working sets and warm-ups for each.',
                last: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Add exercise',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: onAddExercise,
              ),
            ],
          ),
        ),
        if (onBrowseTemplates != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Rather start from a plan?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.secondary(t),
                ),
              ),
              AppButton.ghost(
                label: 'Browse templates',
                size: AppButtonSize.small,
                onPressed: onBrowseTemplates,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One numbered step of [_BuildGuide], with a hairline running down to the
/// next so the three read as a sequence.
class _GuideStep extends ConsumerWidget {
  final int number;
  final String title;
  final String detail;
  final bool done;
  final bool last;

  const _GuideStep({
    required this.number,
    required this.title,
    required this.detail,
    this.done = false,
    this.last = false,
  });

  static const double _marker = 28;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                width: _marker,
                height: _marker,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? t.success.withValues(alpha: t.isDark ? 0.18 : 0.14)
                      : t.surface,
                  border: Border.all(
                    color: done
                        ? t.success.withValues(alpha: 0.45)
                        : t.outline,
                  ),
                ),
                child: done
                    ? Icon(Icons.check_rounded, size: 16, color: t.success)
                    : Text(
                        '$number',
                        style: AppType.mono(
                          t,
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    color: t.divider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: last ? 0 : AppSpacing.md + 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppType.body(t).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(detail, style: AppType.secondary(t)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The last slot of the exercise list: an outlined, see-through row that adds
/// the next exercise. Quieter than the Save button below it on purpose.
class _AddExerciseRow extends ConsumerWidget {
  final VoidCallback onTap;

  const _AddExerciseRow({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.985,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: t.outline, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: t.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Add exercise',
                style: AppType.button(t).copyWith(
                  color: t.primary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// The sticky save action.
///
/// Deliberately *not* a full-width glass slab: stacked on top of the floating
/// nav bar that read as two competing panels and ate the bottom third of the
/// screen. A single compact button, carried by its own primary glow, is enough
/// — and it stays out of the way entirely until [visible].
/// ---------------------------------------------------------------------------
class _SaveBar extends StatelessWidget {
  final String label;

  /// Drives the slide-and-fade. Hidden, the bar also stops taking taps so the
  /// content scrolling underneath stays reachable.
  final bool visible;

  final bool loading;
  final VoidCallback? onPressed;

  const _SaveBar({
    required this.label,
    required this.visible,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.75),
        duration: AppMotion.normal,
        curve: visible ? AppMotion.enter : AppMotion.exit,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: visible ? AppMotion.normal : AppMotion.fast,
          curve: AppMotion.standard,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
            ),
            child: Center(
              child: AppButton(
                label: label,
                icon: Icons.check_rounded,
                size: AppButtonSize.large,
                loading: loading,
                onPressed: onPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// The per-exercise sheet: two steppers plus the destructive action. Changes
/// apply as they are made — there is no separate save step.
/// ---------------------------------------------------------------------------
class _EditSetsSheet extends StatefulWidget {
  final int workingSets;
  final int warmUpSets;
  final void Function(int workingSets, int warmUpSets) onChanged;
  final VoidCallback onRemove;

  const _EditSetsSheet({
    required this.workingSets,
    required this.warmUpSets,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_EditSetsSheet> createState() => _EditSetsSheetState();
}

class _EditSetsSheetState extends State<_EditSetsSheet> {
  late int _working = widget.workingSets;
  late int _warmUp = widget.warmUpSets;

  void _apply(int working, int warmUp) {
    setState(() {
      _working = working;
      _warmUp = warmUp;
    });
    widget.onChanged(working, warmUp);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SetStepper(
          label: 'Working sets',
          value: _working,
          min: 1,
          max: 20,
          onChanged: (value) => _apply(value, _warmUp),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SetStepper(
          label: 'Warm-up sets',
          hint: 'Not counted in stats',
          value: _warmUp,
          min: 0,
          max: 10,
          onChanged: (value) => _apply(_working, value),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton.danger(
                label: 'Remove',
                icon: Icons.delete_outline_rounded,
                onPressed: widget.onRemove,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A large, unambiguous −/+ control for one set count.
class _SetStepper extends ConsumerWidget {
  final String label;
  final String? hint;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SetStepper({
    required this.label,
    this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      inset: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(t).copyWith(fontWeight: FontWeight.w700),
                ),
                if (hint != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(hint!, style: AppType.caption(t), maxLines: 2),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppIconButton(
            icon: Icons.remove_rounded,
            size: 40,
            iconSize: 22,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 46,
            child: Center(
              child: SwapTransitionBox(
                value: value,
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: AppType.metric(t, size: 22),
                ),
              ),
            ),
          ),
          AppIconButton(
            icon: Icons.add_rounded,
            size: 40,
            iconSize: 22,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// A standard workout template: what it is at a glance, plus a one-tap copy.
/// The full breakdown lives on [TemplateDetailPage].
/// ---------------------------------------------------------------------------
class _TemplateCard extends ConsumerStatefulWidget {
  final StandardWorkoutTemplate template;

  /// The user already has a program with this template's name.
  final bool alreadyAdded;

  const _TemplateCard({required this.template, required this.alreadyAdded});

  @override
  ConsumerState<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<_TemplateCard> {
  bool _isAdding = false;

  /// Bridges the moment between a successful copy and the programs stream
  /// catching up with it.
  bool _justAdded = false;

  bool get _added => widget.alreadyAdded || _justAdded;

  Future<void> _add() async {
    if (_isAdding || _added) return;
    setState(() => _isAdding = true);

    final ok = await addTemplateToMyWorkouts(context, ref, widget.template);

    if (!mounted) return;
    setState(() {
      _isAdding = false;
      _justAdded = ok;
    });
  }

  void _openDetails() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TemplateDetailPage(template: widget.template),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final template = widget.template;

    final description = template.description.trim();

    // The title shares its line with the action; the description and the
    // level · length footer get the card's full width, so neither wraps a
    // stray word onto a line of its own.
    return AppCard(
      onTap: _openDetails,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.heading(t),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: _actionWidth,
                child: _added
                    ? _AddedBadge(
                        onTap: () => AppSnack.show(
                          context,
                          ref,
                          'Already in your workouts',
                        ),
                      )
                    : Tooltip(
                        message: 'Add to my workouts',
                        excludeFromSemantics: true,
                        child: AppButton.secondary(
                          label: 'Add',
                          icon: Icons.add_rounded,
                          size: AppButtonSize.small,
                          loading: _isAdding,
                          onPressed: _isAdding ? null : _add,
                        ),
                      ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.secondary(t).copyWith(height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            templateSummary(template),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption(t).copyWith(
              color: t.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Fits "Add" and "Added", so the card does not reflow when it flips.
  static const double _actionWidth = 92;
}

/// The template is already one of your workouts — said in the success colour,
/// at the size of the button it replaces.
class _AddedBadge extends ConsumerWidget {
  final VoidCallback onTap;

  const _AddedBadge({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Semantics(
      label: 'In your workouts',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.96,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: t.success.withValues(alpha: t.isDark ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: t.success.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, size: 17, color: t.success),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Added',
                style: AppType.button(t).copyWith(
                  color: t.success,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
