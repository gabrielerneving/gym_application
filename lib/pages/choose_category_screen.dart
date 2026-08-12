import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../widgets/ui/ui.dart';
import 'create_exercise_screen.dart';
import 'exercise_list_screen.dart';

/// Step one of picking an exercise: choose the muscle group.
///
/// Pops the chosen `MasterExercise` all the way back to the caller, so the
/// workout builder only ever sees one result.
class ChooseCategoryScreen extends ConsumerWidget {
  const ChooseCategoryScreen({super.key});

  /// The muscle groups exercises are filed under. Kept verbatim — the strings
  /// are the Firestore category values.
  final List<String> categories = const [
    'Shoulders',
    'Quads',
    'Hamstrings',
    'Glutes',
    // 'Calves' is the canonical name — it is what `DatabaseService.muscleGroups`
    // and the statistics screens use. Exercises saved under the old 'Calf'
    // label are migrated on read, see `getExerciseToMuscleGroupMap`.
    'Calves',
    'Biceps',
    'Triceps',
    'Chest',
    'Back',
    'Abs',
  ];

  /// A recognisable glyph per muscle group.
  static IconData _iconFor(String category) {
    switch (category) {
      case 'Shoulders':
        return Icons.accessibility_new_rounded;
      case 'Quads':
        return Icons.directions_bike_rounded;
      case 'Hamstrings':
        return Icons.directions_run_rounded;
      case 'Glutes':
        return Icons.chair_rounded;
      case 'Calves':
        return Icons.directions_walk_rounded;
      case 'Biceps':
        return Icons.fitness_center_rounded;
      case 'Triceps':
        return Icons.sports_handball_rounded;
      case 'Chest':
        return Icons.self_improvement_rounded;
      case 'Back':
        return Icons.rowing_rounded;
      case 'Abs':
        return Icons.grid_view_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  Future<void> _openCategory(BuildContext context, String category) async {
    final selectedExercise = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) => ExerciseListScreen(category: category),
      ),
    );

    if (selectedExercise != null && context.mounted) {
      Navigator.of(context).pop(selectedExercise);
    }
  }

  Future<void> _createExercise(BuildContext context) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) => const CreateExerciseScreen(),
      ),
    );

    // A freshly created exercise goes straight back to the workout builder.
    if (result != null && context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppScaffold(
      title: 'Choose exercise',
      subtitle: 'Start with a muscle group',
      bottomPadding: AppSpacing.xxxl,
      actions: [
        AppIconButton(
          icon: Icons.add_rounded,
          onPressed: () => _createExercise(context),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            0,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = categories[index];
                return FadeSlideIn(
                  index: index,
                  child: _CategoryCard(
                    label: category,
                    icon: _iconFor(category),
                    color: t.dataColor(index),
                    onTap: () => _openCategory(context, category),
                  ),
                );
              },
              childCount: categories.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xxl,
            AppSpacing.screenH,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: AppButton.outline(
              label: 'Create a new exercise',
              icon: Icons.add_rounded,
              expand: true,
              onPressed: () => _createExercise(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// One tappable muscle-group tile.
class _CategoryCard extends ConsumerWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color, size: 46, iconSize: 23),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.heading(t),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'Browse',
                style: AppType.caption(t).copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 15, color: color),
            ],
          ),
        ],
      ),
    );
  }
}
