import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/ui/ui.dart';

/// ---------------------------------------------------------------------------
/// Volume — how much work each muscle group is actually getting.
///
/// Everything comes from [trainingDataProvider] (one cached read of the session
/// history) and [AnalyticsService]: period totals with a comparison against the
/// previous window, weekly sets per muscle group scored against the user's own
/// set band from [TrainingGoals], a 12-week tonnage trend, and a short list of
/// what to add next.
/// ---------------------------------------------------------------------------
class VolumeTrackerScreen extends ConsumerWidget {
  const VolumeTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final async = ref.watch(trainingDataProvider);

    return async.when(
      loading: () => const AppScaffold(
        title: 'Volume',
        headerBottom: _PeriodSelector(),
        children: [_LoadingSkeleton()],
      ),
      error: (error, _) => AppScaffold(
        title: 'Volume',
        subtitle: period.longLabel,
        headerBottom: const _PeriodSelector(),
        body: ErrorState(
          message: 'Could not load your training history.',
          onRetry: () {
            ref.invalidate(workoutSessionsProvider);
            ref.invalidate(exerciseMuscleMapProvider);
          },
        ),
      ),
      data: (data) {
        final range = period.range();
        final summary = AnalyticsService.summarize(data.sessions, range);

        if (data.isEmpty || summary.current.sets == 0) {
          // When there is history but not in this window, the useful action is
          // widening the window rather than sending the user away.
          final canWiden = !data.isEmpty && period != StatsPeriod.all;
          final VoidCallback action = canWiden
              ? () {
                  ref.read(statsPeriodProvider.notifier).state =
                      StatsPeriod.all;
                }
              : () {
                  Navigator.of(context).maybePop();
                };

          return AppScaffold(
            title: 'Volume',
            subtitle: period.longLabel,
            headerBottom: const _PeriodSelector(),
            onRefresh: () => _refresh(ref),
            body: EmptyState(
              icon: Icons.bar_chart_rounded,
              title: data.isEmpty
                  ? 'No workouts yet'
                  : 'Nothing logged in this window',
              message: data.isEmpty
                  ? 'Finish a workout and your weekly volume shows up here.'
                  : 'No working sets in ${period.longLabel.toLowerCase()}. '
                      'Widen the window to see older training.',
              actionLabel: canWiden ? 'Show all time' : 'Log a workout',
              onAction: action,
            ),
          );
        }

        final weeks = _weeksFor(period, data);
        final balance = AnalyticsService.muscleBalance(
          data.sessions,
          data.exerciseToMuscle,
          weeks: weeks,
          goals: data.goals,
        );
        final currentSets = AnalyticsService.muscleGroupSets(
          data.sessions,
          data.exerciseToMuscle,
          range: range,
        );
        final previousSets = AnalyticsService.muscleGroupSets(
          data.sessions,
          data.exerciseToMuscle,
          range: range.previous(),
        );
        final lagging = AnalyticsService.weakestGroups(balance, limit: 3)
            .where((m) => m.setsPerWeek < m.targetMin)
            .toList();

        return AppScaffold(
          title: 'Volume',
          subtitle: period.longLabel,
          headerBottom: const _PeriodSelector(),
          onRefresh: () => _refresh(ref),
          children: [
            const SizedBox(height: AppSpacing.sm),
            // A slightly taller tile than the kit default: these two carry a
            // label, a big number, a unit and a delta badge.
            StatGrid(
              aspectRatio: 1.1,
              children: [
                StatTile(
                  label: 'Working sets',
                  value: summary.current.sets.toDouble(),
                  unit: 'sets',
                  icon: Icons.repeat_rounded,
                  highlight: true,
                  delta: summary.hasComparison ? summary.setsChange : null,
                  deltaIsPercent: true,
                ),
                StatTile(
                  label: 'Tonnage',
                  valueText: AppFormat.compact(summary.current.volume),
                  unit: 'kg',
                  icon: Icons.fitness_center_rounded,
                  delta: summary.hasComparison ? summary.volumeChange : null,
                  deltaIsPercent: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(index: 2, child: _PeriodFacts(summary: summary)),
            const SectionHeader(
              title: 'Weekly volume',
              subtitle: 'Tonnage per week, last 12 weeks',
            ),
            FadeSlideIn(index: 3, child: _WeeklyVolumeCard(buckets: data.weeklyVolume)),
            SectionHeader(
              title: 'Muscle balance',
              subtitle: '${_weeksLabel(weeks)} · target '
                  '${data.goals.bandLabel} sets per week',
            ),
            FadeSlideIn(
              index: 4,
              child: _BalanceCard(
                balance: balance,
                currentSets: currentSets,
                previousSets: previousSets,
                periodLabel: period.longLabel.toLowerCase(),
              ),
            ),
            const SectionHeader(title: 'What to add'),
            FadeSlideIn(
              index: 5,
              child: _Recommendations(lagging: lagging, goals: data.goals),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _MethodNote(),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// How many weeks the muscle-group average should be taken over for the
/// selected period. Keeps "sets per week" honest when the window changes.
int _weeksFor(StatsPeriod period, TrainingData data) {
  switch (period) {
    case StatsPeriod.week:
      return 1;
    case StatsPeriod.month:
      return 4;
    case StatsPeriod.quarter:
      return 13;
    case StatsPeriod.year:
      return 52;
    case StatsPeriod.all:
      if (data.sessions.isEmpty) return 4;
      final oldest = data.sessions
          .map((s) => s.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final days = DateTime.now().difference(oldest).inDays;
      return math.max(1, (days / 7).ceil());
  }
}

String _weeksLabel(int weeks) =>
    weeks == 1 ? 'This week' : 'Average over $weeks weeks';

Color _statusColor(AppColors t, VolumeStatus status) {
  switch (status) {
    case VolumeStatus.low:
      return t.warning;
    case VolumeStatus.optimal:
      return t.success;
    case VolumeStatus.high:
      return t.primary;
    case VolumeStatus.none:
      return t.textTertiary;
  }
}

Future<void> _refresh(WidgetRef ref) async {
  ref.invalidate(workoutSessionsProvider);
  ref.invalidate(exerciseMuscleMapProvider);
  try {
    await ref.read(trainingDataProvider.future);
  } catch (_) {
    // The error state renders on the next build; nothing to do here.
  }
}

// ---------------------------------------------------------------------------
// Period selection
// ---------------------------------------------------------------------------

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);

    return AppSegmented<StatsPeriod>(
      value: period,
      segments: [
        for (final p in StatsPeriod.values) AppSegment(value: p, label: p.label),
      ],
      onChanged: (value) =>
          ref.read(statsPeriodProvider.notifier).state = value,
    );
  }
}

// ---------------------------------------------------------------------------
// Headline
// ---------------------------------------------------------------------------

class _PeriodFacts extends ConsumerWidget {
  final PeriodSummary summary;

  const _PeriodFacts({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final totals = summary.current;
    final setsPerWorkout =
        totals.workouts == 0 ? 0.0 : totals.sets / totals.workouts;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricRow(
            label: 'Workouts',
            value: '${totals.workouts}',
            icon: Icons.event_rounded,
            trailing: summary.hasComparison
                ? DeltaBadge(
                    delta: summary.workoutsChange,
                    percent: true,
                    compact: true,
                    fontSize: 11.5,
                  )
                : null,
          ),
          MetricRow(
            label: 'Sets per workout',
            value: AppFormat.weight(setsPerWorkout),
            icon: Icons.repeat_rounded,
          ),
          MetricRow(
            label: 'Volume per workout',
            value: '${AppFormat.compact(totals.avgVolume)} kg',
            icon: Icons.fitness_center_rounded,
          ),
          MetricRow(
            label: 'Total reps',
            value: '${totals.reps}',
            icon: Icons.format_list_numbered_rounded,
          ),
          MetricRow(
            label: 'Time under the bar',
            value: AppFormat.duration(totals.minutes),
            icon: Icons.schedule_rounded,
            trailing: summary.hasComparison
                ? DeltaBadge(
                    delta: summary.minutesChange,
                    percent: true,
                    compact: true,
                    fontSize: 11.5,
                  )
                : null,
          ),
          if (!summary.hasComparison) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No training in the previous window, so there is nothing to '
              'compare against yet.',
              style: AppType.caption(t),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly trend
// ---------------------------------------------------------------------------

class _WeeklyVolumeCard extends ConsumerWidget {
  final List<TimeBucket> buckets;

  const _WeeklyVolumeCard({required this.buckets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    var peak = 0.0;
    var total = 0.0;
    for (final b in buckets) {
      peak = math.max(peak, b.volume);
      total += b.volume;
    }

    if (buckets.isEmpty || peak <= 0) {
      return AppCard(
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'No volume logged in the last 12 weeks.',
              style: AppType.secondary(t),
            ),
          ),
        ),
      );
    }

    final maxY = peak * 1.2;
    final interval = maxY / 4;
    final labelStep = math.max(1, (buckets.length / 4).ceil());
    final average = total / buckets.length;
    final lastIndex = buckets.length - 1;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.show_chart_rounded, size: 15, color: t.primary),
                const SizedBox(width: 6),
                Text(
                  '${AppFormat.compact(average)} kg average per week',
                  style: AppType.secondary(t),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 208,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barGroups: [
                  for (var i = 0; i < buckets.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: buckets[i].volume,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: i == lastIndex
                              ? null
                              : t.primary.withValues(alpha: t.isDark ? 0.38 : 0.30),
                          gradient: i == lastIndex
                              ? LinearGradient(
                                  colors: [t.primaryLight, t.primary],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                        ),
                      ],
                    ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  drawHorizontalLine: true,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: t.divider,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: interval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          AppFormat.compact(value),
                          style: AppType.caption(t).copyWith(fontSize: 10.5),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= buckets.length) {
                          return const SizedBox.shrink();
                        }
                        if (index % labelStep != 0 && index != lastIndex) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            AppFormat.dayMonth(buckets[index].start),
                            style: AppType.caption(t).copyWith(fontSize: 10.5),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is FlTapDownEvent && response?.spot != null) {
                      HapticStrength.selection.fire();
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => t.elevated,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final index = math.min(
                        math.max(group.x.toInt(), 0),
                        buckets.length - 1,
                      );
                      final bucket = buckets[index];
                      return BarTooltipItem(
                        'Week of ${AppFormat.dayMonth(bucket.start)}\n'
                        '${AppFormat.compact(bucket.volume)} kg · '
                        '${bucket.sets} sets',
                        AppType.caption(t).copyWith(
                          color: t.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Muscle balance
// ---------------------------------------------------------------------------

class _BalanceCard extends ConsumerWidget {
  final List<MuscleBalance> balance;
  final Map<String, int> currentSets;
  final Map<String, int> previousSets;
  final String periodLabel;

  const _BalanceCard({
    required this.balance,
    required this.currentSets,
    required this.previousSets,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    if (balance.isEmpty) {
      return AppCard(
        child: Text(
          'No muscle groups to score yet.',
          style: AppType.secondary(t),
        ),
      );
    }

    // Every group carries the band it was scored against, so the axis clears
    // the top of the user's target before it stretches for the tallest bar:
    // a 3–6 band and a 25–35 one both stay fully inside the track.
    final peak = balance.first;
    final maxScale = math.max(peak.targetMax * 1.2, peak.setsPerWeek * 1.12);
    final unmapped = currentSets['Other'] ?? 0;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < balance.length; i++)
            FadeSlideIn(
              index: i,
              offsetY: 12,
              child: _MuscleRow(
                muscle: balance[i],
                maxScale: maxScale,
                periodSets: currentSets[balance[i].group] ?? 0,
                previousPeriodSets: previousSets[balance[i].group] ?? 0,
                periodLabel: periodLabel,
              ),
            ),
          if (unmapped > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, thickness: 1, color: t.divider),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: t.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '$unmapped sets in $periodLabel came from exercises with no '
                    'muscle group. Assign one in your exercise library to score '
                    'them here.',
                    style: AppType.caption(t).copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MuscleRow extends ConsumerWidget {
  final MuscleBalance muscle;
  final double maxScale;
  final int periodSets;
  final int previousPeriodSets;
  final String periodLabel;

  const _MuscleRow({
    required this.muscle,
    required this.maxScale,
    required this.periodSets,
    required this.previousPeriodSets,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = _statusColor(t, muscle.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatBar(
            label: muscle.group,
            value: muscle.setsPerWeek,
            max: maxScale,
            valueLabel: '${AppFormat.weight(muscle.setsPerWeek)} /wk',
            color: tone,
            targetMin: muscle.targetMin,
            targetMax: muscle.targetMax,
          ),
          Row(
            children: [
              AppBadge(
                label: muscle.statusLabel,
                color: tone,
                fontSize: 10.5,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$periodSets sets in $periodLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t),
                ),
              ),
              DeltaBadge(
                delta: periodSets - previousPeriodSets,
                compact: true,
                fontSize: 11,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recommendations
// ---------------------------------------------------------------------------

class _Recommendations extends ConsumerWidget {
  final List<MuscleBalance> lagging;

  /// The band the groups were scored against. Needed for the all-clear copy,
  /// which has no lagging group left to read the floor off.
  final TrainingGoals goals;

  const _Recommendations({required this.lagging, required this.goals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    if (lagging.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            IconBadge(
              icon: Icons.check_circle_rounded,
              color: t.success,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Nothing is lagging', style: AppType.heading(t)),
                  const SizedBox(height: 3),
                  Text(
                    'Every muscle group is at or above the '
                    '${goals.weeklySetsMin} sets per week floor.',
                    style: AppType.secondary(t),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lagging.length; i++) ...[
            if (i != 0) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, thickness: 1, color: t.divider),
              const SizedBox(height: AppSpacing.md),
            ],
            _RecommendationRow(muscle: lagging[i]),
          ],
        ],
      ),
    );
  }
}

class _RecommendationRow extends ConsumerWidget {
  final MuscleBalance muscle;

  const _RecommendationRow({required this.muscle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = _statusColor(t, muscle.status);
    final missing = math.max(1, (muscle.targetMin - muscle.setsPerWeek).ceil());

    return Row(
      children: [
        IconBadge(icon: Icons.trending_up_rounded, color: tone),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(muscle.group, style: AppType.heading(t)),
              const SizedBox(height: 3),
              Text(
                muscle.status == VolumeStatus.none
                    ? 'Not trained at all. Start with '
                        '${muscle.targetMin.toInt()} sets a week.'
                    : 'At ${AppFormat.weight(muscle.setsPerWeek)} sets a week. '
                        'Add about $missing more.',
                style: AppType.secondary(t),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppBadge(label: '+$missing', color: tone, icon: Icons.add_rounded),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

class _MethodNote extends ConsumerWidget {
  const _MethodNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: t.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'A working set is any non-warm-up set with weight and reps. '
              'Tonnage is weight × reps summed over those sets. Weeks start on '
              'Monday.',
              style: AppType.caption(t).copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 150)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonCard(height: 150)),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(height: 180),
        SizedBox(height: AppSpacing.xl),
        SkeletonCard(height: 240),
        SizedBox(height: AppSpacing.xl),
        SkeletonCard(height: 260),
      ],
    );
  }
}
