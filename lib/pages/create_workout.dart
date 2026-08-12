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
/// Two modes share this screen:
///   * **create** — reached as the "Create" tab of `MainScreen`. Shows a
///     Build/Templates switcher and reports back through [onWorkoutSaved].
///   * **edit** — pushed as a route with [workoutToEdit]. Templates are hidden
///     and saving updates the existing program in place.
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

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  List<Exercise> _exercises = <Exercise>[];
  late Stream<List<StandardWorkoutTemplate>> _templateStream;

  bool _isLoading = false;
  bool _isReordering = false;
  int _tab = _tabBuild;

  bool get _isEditMode => widget.workoutToEdit != null;

  /// The save bar stays disabled until the workout has a name and at least one
  /// exercise.
  bool get _canSave =>
      !_isLoading &&
      _nameController.text.trim().isNotEmpty &&
      _exercises.isNotEmpty;

  int get _totalSets =>
      _exercises.fold<int>(0, (sum, exercise) => sum + exercise.sets);

  @override
  void initState() {
    super.initState();

    // Edit mode: prefill the form from the program being edited.
    if (widget.workoutToEdit != null) {
      _nameController.text = widget.workoutToEdit!.title;
      _exercises = List<Exercise>.from(widget.workoutToEdit!.exercises);
    }

    _nameController.addListener(_onNameChanged);
    _templateStream = StandardWorkoutService.getStandardWorkouts();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
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

    // The library entry becomes a fresh instance in *this* workout, with its
    // own id so the same movement can appear twice.
    setState(() {
      _exercises.add(
        Exercise(
          id: const Uuid().v4(),
          name: result.name,
          sets: 1,
          workingSets: 1,
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
      subtitle: 'Working sets count towards your statistics',
      builder: (sheetContext) => _EditSetsSheet(
        workingSets: exercise.workingSets,
        warmUpSets: exercise.warmUpSets,
        onChanged: (working, warmUp) => _applySets(exercise, working, warmUp),
        onRemove: () {
          Navigator.of(sheetContext).pop();
          _confirmRemove(exercise);
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

  Future<void> _confirmRemove(Exercise exercise) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Remove exercise?',
      message: '${exercise.name} will be removed from this workout.',
      confirmLabel: 'Remove',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _exercises.removeWhere((e) => e.id == exercise.id);
      if (_exercises.length < 2) _isReordering = false;
    });

    if (mounted) {
      AppSnack.show(context, ref, '${exercise.name} removed');
    }
  }

  void _toggleReordering() {
    FocusScope.of(context).unfocus();
    setState(() => _isReordering = !_isReordering);
  }

  // ---------------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------------

  Future<void> _saveWorkout() async {
    final title = _nameController.text.trim();

    if (title.isEmpty) {
      AppSnack.show(context, ref, 'Give the workout a name first.',
          isError: true);
      return;
    }
    if (_exercises.isEmpty) {
      AppSnack.show(context, ref, 'Add at least one exercise.', isError: true);
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

      FocusManager.instance.primaryFocus?.unfocus();

      if (!mounted) return;

      AppSnack.show(
        context,
        ref,
        widget.workoutToEdit != null ? 'Workout updated' : 'Workout saved',
      );

      _nameController.clear();
      setState(() {
        _exercises.clear();
        _isReordering = false;
      });

      // Hand control back to the shell, or pop when pushed as a route.
      if (widget.onWorkoutSaved != null) {
        widget.onWorkoutSaved!(0); // 0 = Home tab
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnack.show(context, ref, 'Could not save the workout: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  String get _builderSubtitle {
    if (_isReordering) return 'Drag the rows into the order you want';
    if (_exercises.isEmpty) return 'Name it, then add your exercises';
    final count = _exercises.length;
    return '$count exercise${count == 1 ? '' : 's'} · $_totalSets sets';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final isEdit = _isEditMode;
    final showBuilder = isEdit || _tab == _tabBuild;

    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;

    // In tab mode the floating nav bar overlays the bottom of the screen, so
    // the sticky save bar has to clear it. Pushed as a route there is no bar.
    final double navClearance = isEdit ? 0 : NavBarMetrics.totalHeight;
    final double barBottom = keyboard > 0
        ? keyboard + AppSpacing.sm
        : media.padding.bottom + (isEdit ? AppSpacing.md : navClearance);

    return Stack(
      fit: StackFit.expand,
      children: [
        AppScaffold(
          title: isEdit ? 'Edit workout' : 'Create workout',
          subtitle:
              showBuilder ? _builderSubtitle : 'Curated programs, ready to copy',
          showBack: isEdit,
          bottomPadding: showBuilder
              ? (isEdit ? 108.0 : AppSpacing.navBarClearance + 92)
              : AppSpacing.navBarClearance,
          actions: [
            if (showBuilder && _exercises.length > 1)
              AppIconButton(
                icon: _isReordering
                    ? Icons.check_rounded
                    : Icons.swap_vert_rounded,
                active: _isReordering,
                onPressed: _toggleReordering,
              ),
          ],
          headerBottom: isEdit
              ? null
              : AppSegmented<int>(
                  value: _tab,
                  segments: const <AppSegment<int>>[
                    AppSegment(
                      value: _tabBuild,
                      label: 'Build',
                      icon: Icons.tune_rounded,
                    ),
                    AppSegment(
                      value: _tabTemplates,
                      label: 'Templates',
                      icon: Icons.star_rounded,
                    ),
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

        // Sticky save bar — floats over the content, above the nav bar.
        if (showBuilder)
          Positioned(
            left: 0,
            right: 0,
            bottom: barBottom,
            child: Material(
              type: MaterialType.transparency,
              child: _SaveBar(
                label: isEdit ? 'Save changes' : 'Save workout',
                enabled: _canSave,
                loading: _isLoading,
                onPressed: _saveWorkout,
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Builder tab
  // ---------------------------------------------------------------------------

  List<Widget> _builderSlivers(AppColors t) {
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
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Overline('Workout name'),
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    style: AppType.body(t).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Push day',
                      counterText: '',
                      prefixIcon: Icon(
                        Icons.edit_rounded,
                        size: 19,
                        color: t.textTertiary,
                      ),
                    ),
                    onSubmitted: (_) => _nameFocus.unfocus(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        sliver: SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Exercises',
            subtitle: _exercises.isEmpty
                ? null
                : (_isReordering
                    ? 'Drag a row by its handle'
                    : 'Tap a row to edit its sets · long-press to drag'),
            padding: const EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.md,
            ),
          ),
        ),
      ),
      if (_exercises.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          sliver: SliverToBoxAdapter(
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xxl,
              ),
              child: SizedBox(
                height: 288,
                child: EmptyState(
                  icon: Icons.fitness_center_rounded,
                  title: 'No exercises yet',
                  message:
                      'Pick movements from your library to build this workout.',
                  actionLabel: 'Add exercise',
                  onAction: _navigateAndAddExercise,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        )
      else ...[
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xs,
            AppSpacing.screenH,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: AppButton.secondary(
              label: 'Add exercise',
              icon: Icons.add_rounded,
              expand: true,
              onPressed: _navigateAndAddExercise,
            ),
          ),
        ),
      ],
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
                    SkeletonCard(height: 210),
                    SizedBox(height: AppSpacing.lg),
                    SkeletonCard(height: 210),
                    SizedBox(height: AppSpacing.lg),
                    SkeletonCard(height: 210),
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
                message:
                    'Curated programs will show up here. In the meantime you '
                    'can build your own.',
                actionLabel: 'Build a workout',
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
                (context, index) => FadeSlideIn(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _TemplateCard(template: templates[index]),
                  ),
                ),
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
/// The sticky save bar.
/// ---------------------------------------------------------------------------
class _SaveBar extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _SaveBar({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: GlassSurface(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: AppButton(
          label: label,
          icon: Icons.check_rounded,
          expand: true,
          size: AppButtonSize.large,
          loading: loading,
          onPressed: enabled ? onPressed : null,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// The per-exercise sheet: two steppers plus the destructive action.
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
    // Applied straight away — the sheet has no separate save step.
    widget.onChanged(working, warmUp);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final t = ref.watch(themeProvider);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SetStepper(
              label: 'Working sets',
              hint: 'Counted in your statistics',
              icon: Icons.bolt_rounded,
              accent: t.primary,
              value: _working,
              min: 1,
              max: 20,
              onChanged: (value) => _apply(value, _warmUp),
            ),
            const SizedBox(height: AppSpacing.md),
            _SetStepper(
              label: 'Warm-up sets',
              hint: 'Left out of your statistics',
              icon: Icons.local_fire_department_rounded,
              accent: t.warning,
              value: _warmUp,
              min: 0,
              max: 10,
              onChanged: (value) => _apply(_working, value),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              inset: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: MetricRow(
                label: 'Total sets',
                value: '${_working + _warmUp}',
                icon: Icons.format_list_numbered_rounded,
              ),
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
      },
    );
  }
}

/// A large, unambiguous −/+ control for one set count.
class _SetStepper extends ConsumerWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Color accent;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _SetStepper({
    required this.label,
    required this.hint,
    required this.icon,
    required this.accent,
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
                Row(
                  children: [
                    Icon(icon, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.heading(t).copyWith(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(hint, style: AppType.caption(t), maxLines: 2),
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
/// A standard workout template, with the "copy to my workouts" action.
/// ---------------------------------------------------------------------------
class _TemplateCard extends ConsumerStatefulWidget {
  final StandardWorkoutTemplate template;

  const _TemplateCard({required this.template});

  @override
  ConsumerState<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<_TemplateCard> {
  bool _isAdding = false;
  bool _added = false;

  Future<void> _addToMyWorkouts() async {
    if (_isAdding || _added) return;

    setState(() => _isAdding = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          AppSnack.show(context, ref, 'You need to be signed in.',
              isError: true);
          setState(() => _isAdding = false);
        }
        return;
      }

      await DatabaseService(uid: user.uid)
          .saveStandardWorkoutAsOwn(widget.template);

      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _added = true;
      });
      AppSnack.show(
        context,
        ref,
        '"${widget.template.title}" added to your workouts',
      );

      // Keep the confirmation on screen for a moment before re-arming.
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _added = false);
    } catch (e) {
      if (mounted) {
        AppSnack.show(context, ref, 'Could not add the workout: $e',
            isError: true);
        setState(() {
          _isAdding = false;
          _added = false;
        });
      }
    }
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

    return AppCard(
      onTap: _openDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.star_rounded),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      template.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.heading(t).copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      template.category,
                      style: AppType.caption(t).copyWith(
                        color: t.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.textTertiary, size: 22),
            ],
          ),
          if (template.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              template.description,
              style: AppType.secondary(t).copyWith(height: 1.45),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(
                label: '${template.exercises.length} exercises',
                color: t.dataColor(1),
                icon: Icons.fitness_center_rounded,
              ),
              AppBadge(
                label: AppFormat.duration(template.estimatedDurationMinutes),
                color: t.dataColor(2),
                icon: Icons.schedule_rounded,
              ),
              if (template.type.isNotEmpty)
                AppBadge(
                  label: template.type,
                  color: t.dataColor(4),
                  icon: Icons.category_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_added)
            const AppButton.secondary(
              label: 'Added to my workouts',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: null,
            )
          else
            AppButton.secondary(
              label: 'Add to my workouts',
              icon: Icons.add_rounded,
              expand: true,
              loading: _isAdding,
              onPressed: _isAdding ? null : _addToMyWorkouts,
            ),
        ],
      ),
    );
  }
}
