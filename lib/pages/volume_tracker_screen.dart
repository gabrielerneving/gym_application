import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/stats_components.dart';
import '../widgets/ui/ui.dart';
import 'muscle_groups_screen.dart';

/// ---------------------------------------------------------------------------
/// Volume — how much work, and where it changed.
///
/// Everything comes from [trainingDataProvider] (one cached read of the session
/// history) and [AnalyticsService]: the period's sets and tonnage against the
/// window before, what an average workout looks like, a 12-week tonnage trend,
/// and the change in sets per muscle group. Scoring those groups against the
/// weekly target lives on [MuscleGroupsScreen]; this screen links there rather
/// than repeating it.
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
                  : 'No working sets in the '
                      '${period.longLabel.toLowerCase()}. Widen the window to '
                      'see older training.',
              actionLabel: canWiden ? 'Show all time' : 'Log a workout',
              onAction: action,
            ),
          );
        }

        final comparison = summary.hasComparison ? period.comparisonLabel : null;
        final firstSession = data.sessions
            .map((s) => s.date)
            .reduce((a, b) => a.isBefore(b) ? a : b);

        return AppScaffold(
          title: 'Volume',
          subtitle: comparison == null
              ? period.longLabel
              : '${period.longLabel} · $comparison',
          headerBottom: const _PeriodSelector(),
          onRefresh: () => _refresh(ref),
          children: [
            const SizedBox(height: AppSpacing.sm),
            FadeSlideIn(child: _Headline(summary: summary)),
            const SectionHeader(title: 'Weekly tonnage'),
            FadeSlideIn(
              index: 3,
              child: _WeeklyVolumeCard(
                buckets: data.weeklyVolume,
                firstSession: firstSession,
              ),
            ),
            SectionHeader(
              title: 'Sets by muscle',
              subtitle: comparison,
              action: 'Balance',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MuscleGroupsScreen(),
                ),
              ),
            ),
            FadeSlideIn(
              index: 4,
              child: _MuscleChangeCard(
                current: data.muscleSetsFor(period),
                previous: AnalyticsService.muscleGroupSets(
                  data.sessions,
                  data.exerciseToMuscle,
                  range: range.previous(),
                ),
                showChange: summary.hasComparison,
              ),
            ),
            const _MethodNote(),
          ],
        );
      },
    );
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

/// The period's tonnage as the headline, with sets, reps and what an average
/// workout looked like under it.
class _Headline extends StatelessWidget {
  final PeriodSummary summary;

  const _Headline({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totals = summary.current;

    return StatsHeadlineCard(
      value: totals.volume,
      format: AppFormat.compact,
      unit: 'kg lifted',
      delta: summary.deltaOf(summary.previous.volume, summary.volumeChange),
      metrics: [
        HeadlineMetric(
          label: 'Working sets',
          value: '${totals.sets}',
          delta: summary.deltaOf(summary.previous.sets, summary.setsChange),
        ),
        HeadlineMetric(label: 'Total reps', value: _thousands(totals.reps)),
        HeadlineMetric(
          label: 'Sets per workout',
          // Rounded first, so 12.98 reads "13" rather than "13.0".
          value: AppFormat.weight((totals.avgSets * 10).round() / 10),
        ),
        HeadlineMetric(
          label: 'Tonnage per workout',
          value: AppFormat.compact(totals.avgVolume),
          unit: 'kg',
        ),
      ],
    );
  }

  /// 2067 → "2,067".
  static String _thousands(int value) {
    final digits = value.abs().toString();
    final out = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

class _WeeklyVolumeCard extends ConsumerWidget {
  final List<TimeBucket> buckets;

  /// Weeks before the first session are not light weeks, they are no weeks:
  /// they stay out of the average and off the chart.
  final DateTime firstSession;

  const _WeeklyVolumeCard({required this.buckets, required this.firstSession});

  /// Fewest weeks drawn, so a brand-new user still gets a few bars.
  static const int _minWeeks = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final peak = buckets.fold<double>(0, (m, b) => math.max(m, b.volume));

    if (buckets.isEmpty || peak <= 0) {
      return AppCard(
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'No tonnage logged in the last 12 weeks.',
              style: AppType.secondary(t),
            ),
          ),
        ),
      );
    }

    // Average over complete weeks the user was training in. The current week
    // is only part-way through and would drag it down.
    final firstWeek = AnalyticsService.weekStart(firstSession);
    final counted = buckets
        .sublist(0, buckets.length - 1)
        .where((b) => !b.start.isBefore(firstWeek))
        .toList();
    final average = counted.isEmpty
        ? null
        : counted.fold<double>(0, (sum, b) => sum + b.volume) / counted.length;

    var start = buckets.indexWhere((b) => !b.start.isBefore(firstWeek));
    if (start < 0) start = buckets.length - 1;
    start = math.min(start, math.max(0, buckets.length - _minWeeks));
    final shown = buckets.sublist(start);
    final lastIndex = shown.length - 1;

    final axis = NiceAxis.of(0, peak, intervals: 4, fromZero: true);
    final labelEvery = shown.length <= 6 ? 1 : (shown.length / 4).ceil();
    final barWidth = shown.length <= 6
        ? 24.0
        : shown.length <= 9
            ? 18.0
            : 13.0;
    final labelStyle = AppType.caption(t).copyWith(fontSize: 10.5);

    // Finished weeks carry the colour; this week is drawn faint because it
    // is still being written, not because it was light.
    final doneFill = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [t.primaryLight, t.primary],
    );
    final inProgress = t.primary.withValues(alpha: t.isDark ? 0.32 : 0.26);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (average != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  AppFormat.compact(average),
                  style: AppType.metric(t, size: 30),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'kg',
                  style: AppType.body(t).copyWith(
                    color: t.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('A week on average', style: AppType.secondary(t)),
            const SizedBox(height: AppSpacing.xl),
          ],
          SizedBox(
            height: 196,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                minY: axis.min,
                maxY: axis.max,
                barGroups: [
                  for (var i = 0; i < shown.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: shown[i].volume,
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: i == lastIndex ? inProgress : null,
                          gradient: i == lastIndex ? null : doneFill,
                        ),
                      ],
                    ),
                ],
                extraLinesData: ExtraLinesData(
                  extraLinesOnTop: true,
                  horizontalLines: [
                    if (average != null)
                      HorizontalLine(
                        y: average,
                        color: t.text.withValues(alpha: 0.55),
                        strokeWidth: 1.4,
                        dashArray: const [4, 4],
                      ),
                  ],
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  drawHorizontalLine: true,
                  horizontalInterval: axis.step,
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
                      reservedSize: 34,
                      interval: axis.step,
                      getTitlesWidget: (value, meta) {
                        if (!axis.isTick(value)) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Text(
                            AppFormat.compact(value),
                            textAlign: TextAlign.right,
                            style: labelStyle,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index > lastIndex) {
                          return const SizedBox.shrink();
                        }
                        // Always name the latest week; skip the regular label
                        // just before it when the two would crowd.
                        final regular = index % labelEvery == 0 &&
                            lastIndex - index >= labelEvery * 0.6;
                        if (index != lastIndex && !regular) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: AppSpacing.sm,
                          fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                          child: Text(
                            AppFormat.dayMonth(shown[index].start),
                            style: labelStyle,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // The axis ends get the lines the grid leaves out.
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    top: BorderSide(color: t.divider),
                    bottom: BorderSide(color: t.outline),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is FlTapDownEvent && response?.spot != null) {
                      HapticStrength.selection.fire();
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => t.elevated,
                    tooltipRoundedRadius: AppRadius.sm,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final index = math.min(
                        math.max(group.x.toInt(), 0),
                        lastIndex,
                      );
                      final bucket = shown[index];
                      final when = index == lastIndex
                          ? 'This week so far'
                          : 'Week of ${AppFormat.dayMonth(bucket.start)}';
                      return BarTooltipItem(
                        '$when\n'
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
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (average != null) ...[
                _LegendDash(color: t.text.withValues(alpha: 0.55)),
                const SizedBox(width: AppSpacing.sm),
                Text('Average', style: AppType.caption(t)),
                const SizedBox(width: AppSpacing.lg),
              ],
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: inProgress,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('This week so far', style: AppType.caption(t)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Legend key for the dashed average line.
class _LegendDash extends StatelessWidget {
  final Color color;

  const _LegendDash({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(width: 4, height: 1.6, color: color),
        ],
      ],
    );
  }
}

/// Working sets per muscle group in the period, each with its change against
/// the window before.
class _MuscleChangeCard extends ConsumerWidget {
  final Map<String, int> current;
  final Map<String, int> previous;
  final bool showChange;

  const _MuscleChangeCard({
    required this.current,
    required this.previous,
    required this.showChange,
  });

  static const String _unmapped = 'Other';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final groups = [
      for (final group in [
        ...AnalyticsService.defaultMuscleGroups,
        _unmapped,
      ])
        if ((current[group] ?? 0) > 0 || (previous[group] ?? 0) > 0) group,
    ]..sort((a, b) => (current[b] ?? 0).compareTo(current[a] ?? 0));

    if (groups.isEmpty) {
      return AppCard(
        child: Text(
          'No sets in this window yet.',
          style: AppType.secondary(t),
        ),
      );
    }

    Widget change(String group) {
      final delta = (current[group] ?? 0) - (previous[group] ?? 0);
      return SizedBox(
        width: 56,
        child: Align(
          alignment: Alignment.centerRight,
          // No change gets a quiet dash, not a "no change" icon beside one.
          child: delta == 0
              ? Text(
                  '–',
                  style: AppType.mono(t, size: 13)
                      .copyWith(color: t.textTertiary),
                )
              : DeltaBadge(delta: delta, compact: true, fontSize: 11.5),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < groups.length; i++)
            FadeSlideIn(
              index: i,
              child: MetricRow(
                label: groups[i] == _unmapped ? 'Uncategorised' : groups[i],
                value: '${current[groups[i]] ?? 0}',
                valueColor: groups[i] == _unmapped ? t.textSecondary : null,
                trailing: showChange ? change(groups[i]) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodNote extends ConsumerWidget {
  const _MethodNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Text(
        'A working set is any non-warm-up set with reps logged. Bodyweight sets '
        'count as sets but add nothing to tonnage. Weeks start on Monday.',
        style: AppType.caption(t).copyWith(height: 1.45),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: AppSpacing.sm),
        SkeletonCard(height: 250),
        SizedBox(height: AppSpacing.xxl),
        SkeletonCard(height: 260),
        SizedBox(height: AppSpacing.xxl),
        SkeletonCard(height: 260),
      ],
    );
  }
}
