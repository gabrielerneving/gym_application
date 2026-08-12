import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../providers/theme_provider.dart';
import '../widgets/ui/ui.dart';
import 'create_workout.dart';

/// A read-only view of a saved program: what it contains and how the sets are
/// planned, before any weights have been logged against it.
class ProgramDetailPage extends ConsumerWidget {
  final WorkoutProgram program;

  const ProgramDetailPage({super.key, required this.program});

  int get _totalSets =>
      program.exercises.fold<int>(0, (sum, ex) => sum + ex.sets);

  int get _workingSets =>
      program.exercises.fold<int>(0, (sum, ex) => sum + ex.workingSets);

  int get _warmUpSets =>
      program.exercises.fold<int>(0, (sum, ex) => sum + ex.warmUpSets);

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateWorkoutScreen(workoutToEdit: program),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = program.exercises;

    final actions = <Widget>[
      AppIconButton(
        icon: Icons.edit_rounded,
        tooltip: 'Edit program',
        onPressed: () => _openEditor(context),
      ),
    ];

    if (exercises.isEmpty) {
      return AppScaffold(
        title: program.title,
        subtitle: 'No exercises yet',
        actions: actions,
        body: EmptyState(
          icon: Icons.playlist_add_rounded,
          title: 'Nothing planned yet',
          message: 'This program has no exercises. Add a few and it is ready '
              'to run.',
          actionLabel: 'Add exercises',
          onAction: () => _openEditor(context),
        ),
      );
    }

    return AppScaffold(
      title: program.title,
      subtitle: '${exercises.length} '
          '${exercises.length == 1 ? 'exercise' : 'exercises'} · '
          '$_totalSets ${_totalSets == 1 ? 'set' : 'sets'}',
      actions: actions,
      children: [
        StatGrid(
          columns: 3,
          aspectRatio: 1.0,
          children: [
            StatTile(
              label: 'Exercises',
              value: exercises.length.toDouble(),
            ),
            StatTile(
              label: 'Working',
              value: _workingSets.toDouble(),
              unit: 'sets',
            ),
            StatTile(
              label: 'Warm-up',
              value: _warmUpSets.toDouble(),
              unit: 'sets',
            ),
          ],
        ),
        const SectionHeader(
          title: 'Exercises',
          subtitle: 'The planned set structure for every movement',
        ),
        for (var i = 0; i < exercises.length; i++)
          FadeSlideIn(
            index: i,
            child: _ExerciseCard(exercise: exercises[i], index: i),
          ),
      ],
    );
  }
}

/// One exercise: its position in the program, its name and how its sets split
/// between working and warm-up work.
class _ExerciseCard extends ConsumerWidget {
  final Exercise exercise;
  final int index;

  const _ExerciseCard({required this.exercise, required this.index});

  /// A, B, C … and plain numbers once the alphabet runs out.
  String get _marker =>
      index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final badges = <Widget>[
      if (exercise.workingSets > 0)
        AppBadge(
          label: '${exercise.workingSets} working',
          icon: Icons.fitness_center_rounded,
        ),
      if (exercise.warmUpSets > 0)
        AppBadge(
          label: '${exercise.warmUpSets} warm-up',
          icon: Icons.local_fire_department_rounded,
          color: t.warning,
        ),
      if (exercise.workingSets <= 0 && exercise.warmUpSets <= 0)
        AppBadge(label: 'No sets planned', color: t.textSecondary),
    ];

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: t.primaryWash,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: t.primaryWashOutline),
                ),
                alignment: Alignment.center,
                child: Text(
                  _marker,
                  style: AppType.mono(t, size: 14, weight: FontWeight.w800)
                      .copyWith(color: t.primary),
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
                      style: AppType.heading(t),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: badges,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (exercise.sets > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            _SetStrip(exercise: exercise),
          ],
        ],
      ),
    );
  }
}

/// The planned sets drawn as a row of chips — flames for warm-ups, numbers for
/// the working sets that actually count towards statistics.
class _SetStrip extends ConsumerWidget {
  final Exercise exercise;

  const _SetStrip({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < exercise.sets; i++)
          _SetChip(
            isWarmUp: i < exercise.warmUpSets,
            number: i - exercise.warmUpSets + 1,
            theme: t,
          ),
      ],
    );
  }
}

class _SetChip extends StatelessWidget {
  final bool isWarmUp;
  final int number;
  final AppColors theme;

  const _SetChip({
    required this.isWarmUp,
    required this.number,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isWarmUp
            ? theme.warning.withValues(alpha: theme.isDark ? 0.16 : 0.11)
            : theme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: isWarmUp ? theme.warning.withValues(alpha: 0.28) : theme.outline,
        ),
      ),
      child: isWarmUp
          ? Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: theme.warning,
            )
          : Text(
              '$number',
              style: AppType.mono(theme, size: 12)
                  .copyWith(color: theme.textSecondary),
            ),
    );
  }
}
