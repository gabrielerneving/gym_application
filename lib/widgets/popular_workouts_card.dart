import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import 'stats_components.dart';
import 'ui/ui.dart';

/// Which programs the user actually runs: each one's share of their sessions,
/// how long it takes and when it was last done.
///
/// Fed straight from [AnalyticsService.programUsage], which arrives sorted by
/// run count, most frequent first. The card has no heading of its own — it
/// sits under a section header that already names it.
///
/// One tone for every bar: the programs are rows of one measure, not
/// categories that need telling apart, and four accent colours read as four
/// different kinds of thing.
class PopularWorkoutsCard extends ConsumerWidget {
  /// Program usage, most frequent first.
  final List<ProgramUsage> programs;

  /// How many rows to render before the list is truncated.
  final int maxItems;

  const PopularWorkoutsCard({
    super.key,
    required this.programs,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final total = programs.fold<int>(0, (sum, p) => sum + p.count);
    final visible =
        programs.length > maxItems ? programs.sublist(0, maxItems) : programs;
    final hidden = programs.length - visible.length;

    return AppCard(
      // The rows carry their own vertical rhythm.
      padding: visible.isEmpty
          ? null
          : const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visible.isEmpty)
            Text(
              'Finish a workout and the programs you run most show up here.',
              style: AppType.secondary(t),
            )
          else ...[
            for (var i = 0; i < visible.length; i++)
              FadeSlideIn(
                index: i,
                child: _ProgramRow(program: visible[i], total: total),
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  '+$hidden more ${hidden == 1 ? 'program' : 'programs'}',
                  style: AppType.caption(t),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One program: name and run count, its share-of-total bar, then its share,
/// average duration and when it was last performed.
class _ProgramRow extends ConsumerWidget {
  final ProgramUsage program;
  final int total;

  const _ProgramRow({required this.program, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final share = total <= 0 ? 0.0 : program.count / total;

    return RangeBar(
      label: program.title,
      value: program.count.toDouble(),
      max: total <= 0 ? 1 : total.toDouble(),
      valueLabel: '${program.count}×',
      color: t.primary,
      caption: '${(share * 100).round()}% of sessions · '
          '${AppFormat.duration(program.avgMinutes.round())} avg · '
          '${AppFormat.relativeDate(program.lastPerformed)}',
    );
  }
}
