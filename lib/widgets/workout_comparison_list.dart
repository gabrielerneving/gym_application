import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../utils/workout_comparison.dart';
import 'ui/ui.dart';

/// "Vs last time": one row per exercise that changed, with every change
/// signed — fewer reps, a lighter top set, a dropped set or a skipped exercise
/// show up as plainly as a new best. Used by the post-workout summary and the
/// history detail page so both tell the same story.
///
/// Laid out like the set tables it sits above: the exercise on the left, the
/// changes right-aligned in their own columns (performance, then sets), so
/// the numbers line up down the list however many of them a row has.
class WorkoutComparisonList extends ConsumerWidget {
  final SessionComparison comparison;

  /// Caps the rows (the rest collapse into "+N more"); null shows them all.
  final int? maxRows;

  const WorkoutComparisonList({
    super.key,
    required this.comparison,
    this.maxRows,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final changes = comparison.exercises;
    final shown =
        maxRows == null ? changes : changes.take(maxRows!).toList();
    final hidden = changes.length - shown.length;

    // Only spend a column on set counts when some row has one.
    final setColumn = shown.any((c) => !c.skipped && c.setDelta != 0);

    final skipped = Text(
      'Skipped',
      style: AppType.caption(t).copyWith(
        color: t.error,
        fontWeight: FontWeight.w700,
        fontSize: 11.5,
      ),
    );

    // A cell right-aligned in its column, with air before it.
    Widget value(Widget? child) => Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Align(
            alignment: Alignment.centerRight,
            child: child ?? const SizedBox.shrink(),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headline(comparison: comparison),
        const SizedBox(height: AppSpacing.sm),
        // A table so each change column is exactly as wide as its widest
        // value, the same on every row; the names take what is left.
        Table(
          columnWidths: <int, TableColumnWidth>{
            0: const FlexColumnWidth(),
            1: const IntrinsicColumnWidth(),
            if (setColumn) 2: const IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final change in shown)
              TableRow(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 30),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        change.exercise,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.secondary(t).copyWith(
                          color: t.text,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  // Nothing to compare for a skipped exercise — only the fact
                  // that it was not done, at the far right like any value.
                  value(
                    change.skipped
                        ? (setColumn ? null : skipped)
                        : _performance(change),
                  ),
                  if (setColumn)
                    value(
                      change.skipped
                          ? skipped
                          : change.setDelta == 0
                              ? null
                              : _badge(change.setDelta, 'set', 'sets'),
                    ),
                ],
              ),
          ],
        ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '+$hidden more',
              style: AppType.caption(t).copyWith(color: t.textSecondary),
            ),
          ),
      ],
    );
  }

  static Widget? _performance(ExerciseChange change) {
    if (change.weightDelta != 0) return _badge(change.weightDelta, 'kg', 'kg');
    if (change.repDelta != 0) return _badge(change.repDelta, 'rep', 'reps');
    return null;
  }

  static Widget _badge(num delta, String singular, String plural) => DeltaBadge(
        delta: delta,
        unit: delta.abs() == 1 ? singular : plural,
        compact: true,
        fontSize: 11.5,
      );
}

/// "VS LAST TIME" on the left, the tally — "3 up · 1 down" — on the right in
/// the colours the rows below use.
class _Headline extends ConsumerWidget {
  final SessionComparison comparison;

  const _Headline({required this.comparison});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final up = comparison.improvements;
    final down = comparison.drops;

    TextStyle tally(Color color) => AppType.caption(t).copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        );

    return Row(
      children: [
        const Expanded(
          child: Overline('Vs last time', padding: EdgeInsets.zero),
        ),
        if (up > 0) Text('$up up', style: tally(t.success)),
        if (up > 0 && down > 0)
          Text('  ·  ', style: tally(t.textTertiary)),
        if (down > 0) Text('$down down', style: tally(t.error)),
      ],
    );
  }
}
