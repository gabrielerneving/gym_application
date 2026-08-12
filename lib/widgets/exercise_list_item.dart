import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise_model.dart';
import '../providers/theme_provider.dart';
import 'ui/ui.dart';

/// One exercise row inside the workout builder.
///
/// Shows the movement name and a breakdown of its sets as badges. The trailing
/// slot is either a drag affordance (while the list is in reorder mode) or an
/// overflow action that opens the per-exercise sheet.
///
/// The constructor is part of the app's public surface — do not change it.
class ExerciseListItem extends ConsumerWidget {
  /// The exercise this row represents.
  final Exercise exercise;

  /// Opens the options sheet for this exercise.
  final VoidCallback onMenuPressed;

  /// True while the parent list is in explicit reorder mode.
  final bool isReordering;

  const ExerciseListItem({
    super.key,
    required this.exercise,
    required this.onMenuPressed,
    this.isReordering = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      // In reorder mode the whole row belongs to the drag gesture, so taps are
      // disabled to avoid opening the sheet mid-drag.
      onTap: isReordering ? null : onMenuPressed,
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.fitness_center_rounded,
            size: 42,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.lg),
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
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppBadge(
                      label: '${exercise.workingSets} working',
                      color: t.primary,
                      icon: Icons.bolt_rounded,
                    ),
                    if (exercise.warmUpSets > 0)
                      AppBadge(
                        label: '${exercise.warmUpSets} warm-up',
                        color: t.warning,
                        icon: Icons.local_fire_department_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (isReordering)
            _DragAffordance(theme: t)
          else
            AppIconButton(
              icon: Icons.more_horiz_rounded,
              onPressed: onMenuPressed,
              filled: false,
              size: 38,
              iconSize: 22,
              color: t.textSecondary,
            ),
        ],
      ),
    );
  }
}

/// The grab handle shown while the list is in reorder mode.
class _DragAffordance extends StatelessWidget {
  final AppColors theme;

  const _DragAffordance({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: theme.primaryWash,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.primaryWashOutline),
      ),
      child: Icon(
        Icons.drag_handle_rounded,
        size: 21,
        color: theme.primary,
      ),
    );
  }
}
