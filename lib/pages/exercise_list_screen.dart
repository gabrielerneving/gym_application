import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/master_exercise_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';
import 'create_exercise_screen.dart';

/// The categories a master exercise can be filed under, in picker order.
/// Kept verbatim — the strings are the Firestore category values.
///
/// 'Calves' is the canonical name — it is what `DatabaseService.muscleGroups`
/// and the statistics screens use. Exercises saved under an old label
/// ('Calf', 'Legs') are read alongside their current name, see
/// [watchExerciseLibrary] and `DatabaseService.legacyCategoryAliases`.
const List<String> exerciseCategories = <String>[
  'Shoulders',
  'Quads',
  'Hamstrings',
  'Glutes',
  'Calves',
  'Biceps',
  'Triceps',
  'Chest',
  'Back',
  'Abs',
  'Cardio',
];

/// The user's exercise library across [categories] (all of them by default),
/// as one live list.
///
/// Built from the per-category streams `DatabaseService` already exposes.
/// Exercises still filed under a legacy category name are included and
/// reported under the name that category has today. Nothing is emitted until
/// every category has delivered its first snapshot, so a search never shows a
/// half-loaded library.
Stream<List<MasterExercise>> watchExerciseLibrary(
  String uid, {
  List<String> categories = exerciseCategories,
}) {
  // Firestore category value -> the category it is shown under.
  final sources = <String, String>{for (final c in categories) c: c};
  DatabaseService.legacyCategoryAliases.forEach((legacy, current) {
    if (categories.contains(current)) sources[legacy] = current;
  });

  final db = DatabaseService(uid: uid);
  final latest = <String, List<MasterExercise>>{};
  final subscriptions = <StreamSubscription<List<MasterExercise>>>[];
  late final StreamController<List<MasterExercise>> controller;

  void emit() {
    if (latest.length < sources.length) return;
    // While a legacy document is being migrated it can briefly show up in
    // both its old and its new category query.
    final seen = <String>{};
    controller.add(<MasterExercise>[
      for (final source in sources.entries)
        for (final exercise in latest[source.key]!)
          if (seen.add(exercise.id))
            source.key == source.value
                ? exercise
                : MasterExercise(
                    id: exercise.id,
                    name: exercise.name,
                    category: source.value,
                  ),
    ]);
  }

  controller = StreamController<List<MasterExercise>>(
    onListen: () {
      for (final source in sources.keys) {
        subscriptions.add(
          db.getMasterExercisesByCategory(source).listen(
            (exercises) {
              latest[source] = exercises;
              emit();
            },
            onError: controller.addError,
          ),
        );
      }
    },
    onCancel: () => Future.wait(subscriptions.map((s) => s.cancel())),
  );

  return controller.stream;
}

/// Case-insensitive name order, which is how people scan a list of lifts.
List<MasterExercise> sortedByName(Iterable<MasterExercise> exercises) {
  return exercises.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Step two of picking an exercise: the movements filed under one category.
///
/// Selecting a row pops it back to the category picker, which forwards it to
/// whoever opened the picker.
class ExerciseListScreen extends ConsumerStatefulWidget {
  final String category;

  const ExerciseListScreen({super.key, required this.category});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  /// Held in state so rebuilds do not resubscribe.
  late Stream<List<MasterExercise>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _openStream();
  }

  Stream<List<MasterExercise>> _openStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return watchExerciseLibrary(uid, categories: <String>[widget.category]);
  }

  Future<void> _createExercise() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) => const CreateExerciseScreen(),
      ),
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.category,
      bottomPadding: AppSpacing.xxxl,
      actions: [
        AppIconButton(
          icon: Icons.add_rounded,
          tooltip: 'New exercise',
          onPressed: _createExercise,
        ),
      ],
      slivers: [
        StreamBuilder<List<MasterExercise>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: 'Could not load the exercises.',
                  onRetry: () => setState(() => _stream = _openStream()),
                ),
              );
            }

            final exercises = snapshot.data;
            if (exercises == null) {
              return const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.sm,
                  AppSpacing.screenH,
                  0,
                ),
                sliver: SliverToBoxAdapter(child: ExercisePickerSkeleton()),
              );
            }

            if (exercises.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.fitness_center_rounded,
                  title: 'Nothing here yet',
                  message: 'No ${widget.category.toLowerCase()} exercises in '
                      'your library.',
                  actionLabel: 'New exercise',
                  onAction: _createExercise,
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
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExercisePickerList(
                      exercises: sortedByName(exercises),
                      onPick: (exercise) => Navigator.of(context).pop(exercise),
                    ),
                    NewExerciseHint(onTap: _createExercise),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Lets the user refile a library exercise under another muscle group.
///
/// Renaming is deliberately not offered: workout history is keyed by the
/// exercise name, so a rename would cut it off from every past set. Moving is
/// safe — statistics look the muscle group up by name, so past sets simply
/// count toward the new group from now on.
Future<void> showMoveExerciseSheet(
  BuildContext context,
  WidgetRef ref,
  MasterExercise exercise,
) {
  return AppSheet.show<void>(
    context: context,
    ref: ref,
    title: exercise.name,
    subtitle: 'Muscle group · past sets count toward the new one',
    builder: (sheetContext) => _MoveExerciseSheet(exercise: exercise),
  );
}

class _MoveExerciseSheet extends ConsumerStatefulWidget {
  final MasterExercise exercise;

  const _MoveExerciseSheet({required this.exercise});

  @override
  ConsumerState<_MoveExerciseSheet> createState() => _MoveExerciseSheetState();
}

class _MoveExerciseSheetState extends ConsumerState<_MoveExerciseSheet> {
  String? _saving;

  Future<void> _move(String category) async {
    final exercise = widget.exercise;
    if (_saving != null) return;
    if (category == exercise.category) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = category);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      // saveMasterExercise writes the document by id, so this updates in
      // place (and also lifts a legacy category name to the current one).
      await DatabaseService(uid: uid).saveMasterExercise(
        MasterExercise(id: exercise.id, name: exercise.name, category: category),
      );
      ref.invalidate(exerciseMuscleMapProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.show(context, ref, '${exercise.name} moved to $category');
    } catch (e) {
      debugPrint('Could not move ${exercise.id}: $e');
      if (!mounted) return;
      setState(() => _saving = null);
      AppSnack.show(context, ref, 'Could not move the exercise. Try again.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final category in exerciseCategories)
          AppChip(
            label: category,
            selected: (_saving ?? widget.exercise.category) == category,
            onTap: () => _move(category),
          ),
      ],
    );
  }
}

/// A grouped list of library exercises; tapping a row picks it, a long press
/// offers to move it to another muscle group. Shared by the category list and
/// the picker's search results.
class ExercisePickerList extends ConsumerWidget {
  final List<MasterExercise> exercises;
  final ValueChanged<MasterExercise> onPick;

  /// Adds the category under each name — for results that mix categories.
  final bool showCategory;

  const ExercisePickerList({
    super.key,
    required this.exercises,
    required this.onPick,
    this.showCategory = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final rows = <Widget>[];
    for (var i = 0; i < exercises.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Divider(height: 1, thickness: 1, color: t.divider),
          ),
        );
      }
      final exercise = exercises[i];
      rows.add(
        FadeSlideIn(
          index: i,
          child: Pressable(
            scale: 0.99,
            onTap: () => onPick(exercise),
            onLongPress: () => showMoveExerciseSheet(context, ref, exercise),
            child: Padding(
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
                          exercise.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body(t).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (showCategory) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            exercise.category,
                            style: AppType.caption(t)
                                .copyWith(color: t.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // The whole row picks; the glyph only says so. Neutral, so a
                  // long list is not a column of accent-coloured pluses.
                  Icon(Icons.add_rounded, size: 20, color: t.textSecondary),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// "Not in your library? New exercise" — the header's "+" spelled out where
/// someone who cannot find a movement is already looking. Sits under the
/// picker's category grid, its search results and a category's list.
class NewExerciseHint extends ConsumerWidget {
  final VoidCallback onTap;

  const NewExerciseHint({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Not in your library?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.secondary(t),
            ),
          ),
          AppButton.ghost(
            label: 'New exercise',
            size: AppButtonSize.small,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder shaped like [ExercisePickerList].
class ExercisePickerSkeleton extends StatelessWidget {
  const ExercisePickerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 48, radius: AppRadius.md),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 48, radius: AppRadius.md),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 48, radius: AppRadius.md),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 48, radius: AppRadius.md),
      ],
    );
  }
}
