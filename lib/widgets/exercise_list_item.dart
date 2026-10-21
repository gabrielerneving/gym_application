import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise_model.dart';
import '../providers/theme_provider.dart';
import 'ui/ui.dart';

/// One exercise row inside the workout builder.
///
/// The movement name over a one-line set breakdown. The trailing slot is a
/// drag handle while the list is in reorder mode, and an options glyph
/// otherwise — the whole row opens the per-exercise sheet.
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

  /// "3 sets", or "3 sets · 1 warm-up" — working sets lead, as they are the
  /// ones that count.
  String get _setsLabel {
    final working = exercise.workingSets;
    final base = '$working ${working == 1 ? 'set' : 'sets'}';
    return exercise.warmUpSets > 0
        ? '$base · ${exercise.warmUpSets} warm-up'
        : base;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      // In reorder mode the whole row belongs to the drag gesture, so taps are
      // disabled to avoid opening the sheet mid-drag.
      onTap: isReordering ? null : onMenuPressed,
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
                  style: AppType.heading(t),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(_setsLabel, style: AppType.secondary(t)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              isReordering
                  ? Icons.drag_handle_rounded
                  : Icons.more_horiz_rounded,
              size: 22,
              color: isReordering ? t.primary : t.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
