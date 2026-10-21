import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/popular_workouts_card.dart';
import '../widgets/stats_components.dart';
import '../widgets/ui/ui.dart';
import 'consistency_screen.dart';
import 'muscle_groups_screen.dart';
import 'one_rm_screen.dart';
import 'progression_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';
import 'volume_tracker_screen.dart';

/// ---------------------------------------------------------------------------
/// StatisticsScreen — the overview of the Stats tab.
///
/// A calm summary with clear ways in, not every metric at once: the headline
/// numbers for the selected period (each against the period before it), a few
/// observations the rest of the page does not already show, then one glance
/// each at volume, consistency and muscle balance — every one of them the door
/// to its own detailed screen.
///
/// Everything is derived from ONE cached fetch of the session history
/// ([trainingDataProvider]) and follows the shared [statsPeriodProvider].
/// ---------------------------------------------------------------------------
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  /// The screen only has room for this many observations before it starts
  /// reading like a report.
  static const int _maxInsights = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trainingDataProvider);
    final period = ref.watch(statsPeriodProvider);

    return async.when(
      loading: () => _shell(
        context,
        ref,
        period,
        body: const _StatisticsSkeleton(),
      ),
      error: (error, _) => _shell(
        context,
        ref,
        period,
        body: ErrorState(
          message: 'Could not load your training data.',
          onRetry: () => ref.invalidate(workoutSessionsProvider),
        ),
      ),
      data: (data) {
        if (data.isEmpty) {
          return _shell(
            context,
            ref,
            period,
            body: EmptyState(
              icon: Icons.insights_rounded,
              title: 'No statistics yet',
              message: 'Finish your first workout and this page fills up with '
                  'trends and records.',
              actionLabel: 'Reload',
              onAction: () => ref.invalidate(workoutSessionsProvider),
            ),
          );
        }

        final summary = data.summaryFor(period);
        final comparison = period.comparisonLabel;
        return _shell(
          context,
          ref,
          period,
          subtitle: summary.hasComparison && comparison != null
              ? '${period.longLabel} · $comparison'
              : period.longLabel,
          children: _sections(context, data, period, summary),
        );
      },
    );
  }

  /// One shell for all four states, so the header, the period selector and
  /// pull-to-refresh never move between loading and content.
  Widget _shell(
    BuildContext context,
    WidgetRef ref,
    StatsPeriod period, {
    String? subtitle,
    Widget? body,
    List<Widget>? children,
  }) {
    return AppScaffold(
      title: 'Statistics',
      subtitle: subtitle ?? period.longLabel,
      // This screen is a tab inside MainScreen — never a pushed route.
      showBack: false,
      actions: [
        AppIconButton(
          icon: Icons.settings_rounded,
          tooltip: 'Settings',
          onPressed: () => _open(context, (context) => const SettingsScreen()),
        ),
      ],
      headerBottom: const _PeriodSelector(),
      onRefresh: () async {
        ref.invalidate(workoutSessionsProvider);
        try {
          await ref.read(trainingDataProvider.future);
        } catch (error) {
          debugPrint('Statistics refresh failed: $error');
        }
      },
      body: body,
      children: children,
    );
  }

  List<Widget> _sections(
    BuildContext context,
    TrainingData data,
    StatsPeriod period,
    PeriodSummary summary,
  ) {
    final insights = data.insights.take(_maxInsights).toList();
    final programs = AnalyticsService.programUsage(data.sessionsFor(period));

    void openVolume() =>
        _open(context, (context) => const VolumeTrackerScreen());
    void openConsistency() =>
        _open(context, (context) => const ConsistencyScreen());
    void openMuscles() =>
        _open(context, (context) => const MuscleGroupsScreen());

    return [
      const SizedBox(height: AppSpacing.sm),
      FadeSlideIn(child: _SummaryCard(summary: summary, period: period)),

      if (insights.isNotEmpty) ...[
        const SectionHeader(title: 'Insights'),
        FadeSlideIn(child: _InsightsCard(insights: insights)),
      ],

      SectionHeader(
        title: 'Weekly volume',
        action: 'Details',
        onAction: openVolume,
      ),
      FadeSlideIn(
        child: _VolumeTrendCard(
          weeks: data.weeklyVolume,
          firstSession: data.sessions
              .map((s) => s.date)
              .reduce((a, b) => a.isBefore(b) ? a : b),
          onTap: openVolume,
        ),
      ),

      SectionHeader(
        title: 'Consistency',
        action: 'Details',
        onAction: openConsistency,
      ),
      FadeSlideIn(
        child: _ConsistencyCard(
          streak: data.streak,
          goal: data.goals.sessionsPerWeek,
          onTap: openConsistency,
        ),
      ),

      SectionHeader(
        title: 'Muscle balance',
        action: 'Details',
        onAction: openMuscles,
      ),
      FadeSlideIn(
        child: _MuscleBalanceCard(
          balance: data.muscleBalanceFor(period),
          goals: data.goals,
          onTap: openMuscles,
        ),
      ),

      if (programs.isNotEmpty) ...[
        const SectionHeader(title: 'Programs'),
        FadeSlideIn(child: PopularWorkoutsCard(programs: programs)),
      ],

      const SectionHeader(title: 'More'),
      const _NavigationGroup(),
    ];
  }
}

void _open(BuildContext context, WidgetBuilder builder) {
  Navigator.of(context).push(MaterialPageRoute(builder: builder));
}

/// The shared period selector, pinned under the title.
class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);

    return AppSegmented<StatsPeriod>(
      value: period,
      segments: [
        for (final value in StatsPeriod.values)
          AppSegment(value: value, label: value.label),
      ],
      onChanged: (value) =>
          ref.read(statsPeriodProvider.notifier).state = value,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Headline numbers: workouts as THE number, the other three under it. The
/// header subtitle says what the badges compare against.
///
/// One card rather than four equal tiles: with four, highlighting one read as
/// "selected", and highlighting none left the page without a lead.
/// ---------------------------------------------------------------------------
class _SummaryCard extends StatelessWidget {
  final PeriodSummary summary;
  final StatsPeriod period;

  const _SummaryCard({required this.summary, required this.period});

  @override
  Widget build(BuildContext context) {
    final current = summary.current;
    final previous = summary.previous;

    return SwapTransitionBox(
      value: period,
      alignment: Alignment.topCenter,
      child: StatsHeadlineCard(
        value: current.workouts.toDouble(),
        unit: current.workouts == 1 ? 'workout' : 'workouts',
        delta: summary.deltaOf(previous.workouts, summary.workoutsChange),
        metrics: [
          HeadlineMetric(
            label: 'Volume',
            value: AppFormat.compact(current.volume),
            unit: 'kg',
            delta: summary.deltaOf(previous.volume, summary.volumeChange),
          ),
          HeadlineMetric(
            label: 'Sets',
            value: '${current.sets}',
            delta: summary.deltaOf(previous.sets, summary.setsChange),
          ),
          HeadlineMetric(
            label: 'Time',
            value: current.hours.toStringAsFixed(1),
            unit: 'h',
            delta: summary.deltaOf(previous.minutes, summary.minutesChange),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Insights — one quiet card, one row per observation.
/// ---------------------------------------------------------------------------
class _InsightsCard extends ConsumerWidget {
  final List<Insight> insights;

  const _InsightsCard({required this.insights});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < insights.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.divider),
            FadeSlideIn(index: i, child: _InsightRow(insight: insights[i])),
          ],
        ],
      ),
    );
  }
}

class _InsightRow extends ConsumerWidget {
  final Insight insight;

  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    // A plateau is an observation, not bad news — it stays neutral.
    final (icon, tone) = switch (insight.kind) {
      InsightKind.positive => (Icons.arrow_upward_rounded, t.success),
      InsightKind.warning => (Icons.arrow_downward_rounded, t.warning),
      InsightKind.suggestion => (Icons.trending_flat_rounded, t.textSecondary),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: t.isDark ? 0.16 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: tone),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centres the title's first line on the 28pt icon disc.
                const SizedBox(height: AppSpacing.xs),
                Text(
                  insight.title,
                  style: AppType.heading(t).copyWith(fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(insight.message, style: AppType.secondary(t)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Weekly tonnage, from the week the user started (up to 12 weeks back).
/// ---------------------------------------------------------------------------
class _VolumeTrendCard extends ConsumerWidget {
  final List<TimeBucket> weeks;

  /// The user's first session, so the comparison is only shown when both
  /// four-week windows are fully inside their history — and so the chart
  /// starts where the history does instead of on a flat run of zeros.
  final DateTime firstSession;

  final VoidCallback onTap;

  const _VolumeTrendCard({
    required this.weeks,
    required this.firstSession,
    required this.onTap,
  });

  /// Whole weeks summed for the headline. The current week is left out of
  /// both sides: it is only part-way through, and counting it made every
  /// Monday look like a drop.
  static const int _window = 4;

  /// Fewest weeks the chart shows, so a brand-new user still gets a shape.
  static const int _minWeeks = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    if (weeks.length < 2) {
      return AppCard(
        child: Text(
          'Not enough history for a trend yet.',
          style: AppType.secondary(t),
        ),
      );
    }

    final complete = weeks.length - 1;
    final recent = _sum(complete - _window, complete);
    final earlier = _sum(complete - 2 * _window, complete - _window);
    final earliestCompared = complete - 2 * _window;
    final firstWeek = AnalyticsService.weekStart(firstSession);
    final comparable = earliestCompared >= 0 &&
        !weeks[earliestCompared].start.isBefore(firstWeek) &&
        earlier > 0;

    // Weeks before the first session are not light weeks, they are no weeks.
    var start = weeks.indexWhere((w) => !w.start.isBefore(firstWeek));
    if (start < 0) start = weeks.length - 1;
    start = math.min(start, math.max(0, weeks.length - _minWeeks));
    final shown = weeks.sublist(start);
    final last = shown.length - 1;

    final peak = shown.fold<double>(0, (m, w) => math.max(m, w.volume));
    final axis = NiceAxis.of(
      0,
      peak <= 0 ? 1000 : peak,
      intervals: 4,
      fromZero: true,
    );
    final labelEvery = shown.length <= 5 ? 1 : (shown.length / 4).ceil();

    final labelStyle = AppType.caption(t).copyWith(fontSize: 10.5);

    final allSpots = [
      for (var i = 0; i <= last; i++) FlSpot(i.toDouble(), shown[i].volume),
    ];

    // Three layers: the area under every week in one piece (two separate
    // fills left a seam where they met), the finished weeks as a solid line,
    // and this week — still being written — dashed to a hollow dot.
    LineChartBarData line(
      List<FlSpot> spots, {
      bool dashed = false,
      bool areaOnly = false,
    }) {
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.26,
        preventCurveOverShooting: true,
        gradient: dashed || areaOnly ? null : t.primaryGradient,
        color: areaOnly
            ? Colors.transparent
            : (dashed ? t.primary.withValues(alpha: 0.75) : null),
        barWidth: areaOnly ? 0 : (dashed ? 2.4 : 3),
        dashArray: dashed ? const [5, 5] : null,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: dashed,
          checkToShowDot: (spot, bar) => spot.x == last,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3.6,
            color: t.card,
            strokeWidth: 2.2,
            strokeColor: t.primary,
          ),
        ),
        belowBarData: BarAreaData(
          show: areaOnly,
          gradient: t.chartFillGradient,
        ),
      );
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      AppFormat.compact(recent),
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
              ),
              if (comparable)
                DeltaBadge(
                  delta: AnalyticsService.percentChange(recent, earlier),
                  percent: true,
                  fontSize: 12.5,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            comparable
                ? 'Last $_window full weeks, vs the $_window before'
                : 'Last $_window full weeks',
            style: AppType.secondary(t),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 168,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: last.toDouble(),
                minY: axis.min,
                maxY: axis.max,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: axis.step,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: t.divider, strokeWidth: 1),
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
                      interval: axis.step,
                      reservedSize: 34,
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
                      interval: labelEvery.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if ((value - index).abs() > 0.01 ||
                            index < 0 ||
                            index > last) {
                          return const SizedBox.shrink();
                        }
                        // Always label the latest week; drop the regular label
                        // just before it when the two would crowd.
                        final regular = index % labelEvery == 0 &&
                            last - index >= labelEvery * 0.6;
                        if (index != last && !regular) {
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
                lineBarsData: [
                  line(allSpots, areaOnly: true),
                  line(allSpots.sublist(0, last)),
                  line(allSpots.sublist(last - 1), dashed: true),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  // One marker per week: the area layer and the repeated
                  // joint between the two lines get none.
                  getTouchedSpotIndicator: (bar, indexes) => [
                    for (final _ in indexes)
                      bar.barWidth == 0
                          ? null
                          : TouchedSpotIndicatorData(
                              FlLine(
                                color: t.primary.withValues(alpha: 0.35),
                                strokeWidth: 1.5,
                              ),
                              FlDotData(
                                getDotPainter: (spot, percent, b, index) =>
                                    FlDotCirclePainter(
                                  radius: 4.5,
                                  color: t.primary,
                                  strokeWidth: 2,
                                  strokeColor: t.card,
                                ),
                              ),
                            ),
                  ],
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => t.elevated,
                    tooltipRoundedRadius: AppRadius.sm,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.round();
                        // The area layer repeats every week, and the dashed
                        // segment's first point repeats the solid line's last.
                        if (spot.barIndex == 0) return null;
                        if (spot.barIndex == 2 && index != last) return null;
                        if (index < 0 || index > last) return null;
                        final week = shown[index];
                        final when = index == last
                            ? 'this week so far'
                            : 'week of ${AppFormat.dayMonth(week.start)}';
                        return LineTooltipItem(
                          '${AppFormat.compact(week.volume)} kg\n$when',
                          AppType.mono(t, size: 12.5),
                        );
                      }).toList();
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

  double _sum(int start, int end) {
    var total = 0.0;
    for (var i = math.max(0, start); i < math.min(weeks.length, end); i++) {
      total += weeks[i].volume;
    }
    return total;
  }
}

/// ---------------------------------------------------------------------------
/// The streak, big, with this week and the longest run beside it.
/// ---------------------------------------------------------------------------
class _ConsistencyCard extends ConsumerWidget {
  final StreakInfo streak;

  /// Sessions a week needs before it counts toward the streak.
  final int goal;

  final VoidCallback onTap;

  const _ConsistencyCard({
    required this.streak,
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                CountUp(
                  value: streak.current.toDouble(),
                  style: AppType.metric(t, size: 40),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'week streak',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(t).copyWith(
                      color: t.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _MiniMetric(
            value: goal > 1
                ? '${streak.thisWeek}/$goal'
                : '${streak.thisWeek}',
            label: 'This week',
          ),
          const SizedBox(width: AppSpacing.xxl),
          _MiniMetric(value: '${streak.longest}', label: 'Longest'),
        ],
      ),
    );
  }
}

class _MiniMetric extends ConsumerWidget {
  final String value;
  final String label;

  const _MiniMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppType.metric(t, size: 21)),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          label,
          style: AppType.caption(t).copyWith(color: t.textSecondary),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Muscle balance at a glance, led by what is going right: the groups on
/// target, or the ones closest to it, then where there is room to grow.
/// ---------------------------------------------------------------------------
class _MuscleBalanceCard extends ConsumerWidget {
  final List<MuscleBalance> balance;

  /// The band the bars are scored against. Passed down beside the balance it
  /// was computed from, so the caption, the range marks and the colours can
  /// never come from different reads of the goal.
  final TrainingGoals goals;

  final VoidCallback onTap;

  const _MuscleBalanceCard({
    required this.balance,
    required this.goals,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final summary = MuscleBalanceSummary.of(balance, goals);
    final bars = summary.closest;

    // The band sits inside the track with room past its top, and every bar
    // shown has to fit.
    var axisMax = goals.setsMax * 1.25;
    for (final group in bars) {
      axisMax = math.max(axisMax, group.setsPerWeek * 1.08);
    }

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.title, style: AppType.heading(t)),
          const SizedBox(height: AppSpacing.xs + 2),
          if (bars.isEmpty)
            Text(summary.subtitle, style: AppType.secondary(t))
          else ...[
            Row(
              children: [
                const RangeLegendGlyph(),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Target ${goals.bandSentence}',
                    style: AppType.secondary(t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < bars.length; i++)
              FadeSlideIn(
                index: i,
                child: RangeBar(
                  label: bars[i].group,
                  value: bars[i].setsPerWeek,
                  max: axisMax,
                  valueLabel: '${AppFormat.weight(bars[i].setsPerWeek)}/wk',
                  color: muscleStatusColor(t, bars[i].status),
                  valueIcon: bars[i].status == VolumeStatus.optimal
                      ? Icons.check_rounded
                      : null,
                  valueIconColor: t.success,
                  rangeMin: goals.setsMin,
                  rangeMax: goals.setsMax,
                ),
              ),
          ],
          if (summary.roomToGrow.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, thickness: 1, color: t.divider),
            const SizedBox(height: AppSpacing.md),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Room to grow  ',
                    style: AppType.secondary(t).copyWith(
                      color: t.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: summary.roomToGrow.map((m) => m.group).join(', '),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.secondary(t),
            ),
          ],
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// The detailed screens that have no card of their own above.
/// ---------------------------------------------------------------------------
class _NavigationGroup extends StatelessWidget {
  const _NavigationGroup();

  @override
  Widget build(BuildContext context) {
    final tiles = [
      AppTile(
        bare: true,
        icon: Icons.emoji_events_rounded,
        title: 'Personal records',
        subtitle: 'Your best set in every exercise',
        onTap: () => _open(context, (context) => const RecordsScreen()),
      ),
      AppTile(
        bare: true,
        icon: Icons.show_chart_rounded,
        title: 'Exercise progression',
        subtitle: 'Track any lift, or compare two',
        onTap: () => _open(context, (context) => const ProgressionScreen()),
      ),
      AppTile(
        bare: true,
        icon: Icons.trending_up_rounded,
        title: '1RM tracker',
        subtitle: 'Maxes and training percentages',
        onTap: () => _open(context, (context) => const OneRMScreen()),
      ),
    ];

    return AppTileGroup(
      children: [
        for (var i = 0; i < tiles.length; i++)
          FadeSlideIn(index: i, child: tiles[i]),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Loading state — shaped like the real overview.
/// ---------------------------------------------------------------------------
class _StatisticsSkeleton extends StatelessWidget {
  const _StatisticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.navBarClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonCard(height: 188),
          SizedBox(height: AppSpacing.xxl),
          SkeletonCard(height: 160),
          SizedBox(height: AppSpacing.xxl),
          SkeletonCard(height: 280),
          SizedBox(height: AppSpacing.xxl),
          SkeletonCard(height: 96),
        ],
      ),
    );
  }
}
