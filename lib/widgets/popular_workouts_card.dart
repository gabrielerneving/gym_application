import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import 'ui/ui.dart';

/// "Most popular workouts" — which programs the user actually runs, how big a
/// share of their training each one is, how long a session takes and when it
/// was last performed.
///
/// Fed straight from [AnalyticsService.programUsage] (`TrainingData.programs`),
/// which arrives sorted by run count, most frequent first.
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.local_fire_department_rounded,
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Most popular workouts',
                      style: AppType.heading(t).copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      programs.isEmpty
                          ? 'No programs logged yet'
                          : '$total sessions across ${programs.length} '
                              '${programs.length == 1 ? 'program' : 'programs'}',
                      style: AppType.caption(t),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text(
                'Finish a workout and the programs you run most often show up '
                'here, with their share of your training.',
                style: AppType.secondary(t),
              ),
            )
          else ...[
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < visible.length; i++)
              FadeSlideIn(
                index: i,
                child: _ProgramRow(
                  program: visible[i],
                  total: total,
                  color: t.dataColor(i),
                ),
              ),
            if (programs.length > visible.length)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  '+${programs.length - visible.length} more '
                  '${programs.length - visible.length == 1 ? 'program' : 'programs'}',
                  style: AppType.caption(t),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One program: name, run count, share-of-total bar, average duration and the
/// date it was last performed.
class _ProgramRow extends ConsumerWidget {
  final ProgramUsage program;
  final int total;
  final Color color;

  const _ProgramRow({
    required this.program,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final share = total <= 0 ? 0.0 : program.count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatBar(
          label: program.title,
          value: program.count.toDouble(),
          max: total <= 0 ? 1 : total.toDouble(),
          valueLabel: '${program.count}× · ${(share * 100).round()}%',
          color: color,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: t.textTertiary),
              const SizedBox(width: 4),
              Text(
                '${AppFormat.duration(program.avgMinutes.round())} avg',
                style: AppType.caption(t),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.history_rounded, size: 13, color: t.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  AppFormat.relativeDate(program.lastPerformed),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
