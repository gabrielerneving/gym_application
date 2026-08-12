import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/popular_workouts_card.dart';
import '../widgets/ui/ui.dart';
import 'consistency_screen.dart';
import 'muscle_groups_screen.dart';
import 'one_rm_screen.dart';
import 'progression_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';
import 'volume_tracker_screen.dart';

/// ---------------------------------------------------------------------------
/// StatisticsScreen — the analytics dashboard.
///
/// Everything on this page is derived from ONE cached fetch of the session
/// history ([trainingDataProvider]) and reacts to the shared period selector
/// ([statsPeriodProvider]). The headline grid always shows the change against
/// the previous window of the same length, which is the whole point of the
/// screen: "am I doing more than last month?".
/// ---------------------------------------------------------------------------
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

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
              message:
                  'Finish your first workout and this page fills up with '
                  'trends, records and insights.',
              actionLabel: 'Reload',
              onAction: () => ref.invalidate(workoutSessionsProvider),
            ),
          );
        }
        return _shell(
          context,
          ref,
          period,
          children: _sections(data, period),
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
    Widget? body,
    List<Widget>? children,
  }) {
    return AppScaffold(
      title: 'Statistics',
      subtitle: period.longLabel,
      // This screen is a tab inside MainScreen — never a pushed route.
      showBack: false,
      actions: [
        AppIconButton(
          icon: Icons.settings_rounded,
          tooltip: 'Settings',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
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

  List<Widget> _sections(TrainingData data, StatsPeriod period) {
    final insights = data.insights.length > 3
        ? data.insights.sublist(0, 3)
        : data.insights;

    return [
      const SizedBox(height: AppSpacing.sm),
      _SummaryGrid(summary: data.summaryFor(period), period: period),

      if (insights.isNotEmpty) ...[
        const SectionHeader(
          title: 'Insights',
          subtitle: 'What your numbers are saying',
        ),
        for (var i = 0; i < insights.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FadeSlideIn(
              index: i,
              child: _InsightCard(insight: insights[i]),
            ),
          ),
      ],

      const SectionHeader(
        title: 'Volume trend',
        subtitle: 'Weekly tonnage, last 12 weeks',
      ),
      FadeSlideIn(child: _VolumeTrendCard(weeks: data.weeklyVolume)),

      const SectionHeader(
        title: 'Consistency',
        subtitle: 'Weeks in a row with at least one session',
      ),
      FadeSlideIn(child: _ConsistencyCard(data: data)),

      const SectionHeader(
        title: 'Muscle balance',
        subtitle: 'Average sets per week, last 4 weeks',
      ),
      FadeSlideIn(
        child: _MuscleBalanceCard(
          balance: data.muscleBalance,
          goals: data.goals,
        ),
      ),

      const SectionHeader(title: 'Programs'),
      FadeSlideIn(child: PopularWorkoutsCard(programs: data.programs)),

      const SectionHeader(title: 'Go deeper'),
      const _NavigationGroup(),
    ];
  }
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
/// Headline numbers, each with its change against the previous equivalent
/// period.
/// ---------------------------------------------------------------------------
class _SummaryGrid extends ConsumerWidget {
  final PeriodSummary summary;
  final StatsPeriod period;

  const _SummaryGrid({required this.summary, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final current = summary.current;
    final previous = summary.previous;

    // With nothing logged in the previous window a percentage change is
    // meaningless, so the badges are hidden instead of reading "+100%".
    final compare = summary.hasComparison;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwapTransitionBox(
          value: period,
          alignment: Alignment.topCenter,
          child: StatGrid(
            aspectRatio: 1.15,
            children: [
              StatTile(
                label: 'Workouts',
                value: current.workouts.toDouble(),
                unit: current.workouts == 1 ? 'session' : 'sessions',
                icon: Icons.event_available_rounded,
                delta: compare ? summary.workoutsChange : null,
                deltaIsPercent: true,
              ),
              StatTile(
                label: 'Total volume',
                valueText: AppFormat.compact(current.volume),
                unit: 'kg',
                icon: Icons.fitness_center_rounded,
                delta: compare ? summary.volumeChange : null,
                deltaIsPercent: true,
              ),
              StatTile(
                label: 'Training time',
                value: current.hours,
                decimals: 1,
                unit: 'h',
                icon: Icons.schedule_rounded,
                delta: compare ? summary.minutesChange : null,
                deltaIsPercent: true,
              ),
              StatTile(
                label: 'Avg session',
                valueText: AppFormat.duration(current.avgDuration.round()),
                icon: Icons.timelapse_rounded,
                delta: compare
                    ? _percentChange(current.avgDuration, previous.avgDuration)
                    : null,
                deltaIsPercent: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              compare
                  ? Icons.compare_arrows_rounded
                  : Icons.info_outline_rounded,
              size: 15,
              color: t.textTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _comparisonNote(period, compare, previous),
                style: AppType.caption(t),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _comparisonNote(
    StatsPeriod period,
    bool compare,
    PeriodTotals previous,
  ) {
    if (period == StatsPeriod.all) {
      return 'All-time totals. Pick a shorter period to compare it with the '
          'one before it.';
    }
    if (!compare) {
      return 'Nothing logged in the previous ${_periodNoun(period)} yet — '
          'comparisons appear as soon as there is.';
    }
    return 'Compared with the previous ${_periodNoun(period)}: '
        '${previous.workouts} '
        '${previous.workouts == 1 ? 'session' : 'sessions'}, '
        '${AppFormat.compact(previous.volume)} kg, '
        '${AppFormat.duration(previous.minutes)}.';
  }
}

/// ---------------------------------------------------------------------------
/// Insights — the analytics engine's plain-language observations.
/// ---------------------------------------------------------------------------
class _InsightCard extends ConsumerWidget {
  final Insight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final tone = switch (insight.kind) {
      InsightKind.positive => t.success,
      InsightKind.warning => t.warning,
      InsightKind.suggestion => t.primary,
    };

    final icon = switch (insight.kind) {
      InsightKind.positive => Icons.check_circle_rounded,
      InsightKind.warning => Icons.warning_amber_rounded,
      InsightKind.suggestion => Icons.lightbulb_rounded,
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      border: Border.all(color: tone.withValues(alpha: t.isDark ? 0.34 : 0.24)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: tone, size: 38, iconSize: 19),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  insight.title,
                  style: AppType.heading(t).copyWith(fontSize: 15.5),
                ),
                const SizedBox(height: 3),
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
/// Weekly tonnage over the last 12 weeks.
/// ---------------------------------------------------------------------------
class _VolumeTrendCard extends ConsumerWidget {
  final List<TimeBucket> weeks;

  const _VolumeTrendCard({required this.weeks});

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

    var peak = 0.0;
    for (final week in weeks) {
      peak = math.max(peak, week.volume);
    }

    // A flat-zero chart still needs a sane axis, otherwise fl_chart is handed
    // a zero interval.
    final maxY = peak <= 0 ? 1000.0 : peak * 1.18;
    final interval = maxY / 3;

    final recent = _sumVolume(weeks, weeks.length - 4, weeks.length);
    final earlier = _sumVolume(weeks, weeks.length - 8, weeks.length - 4);
    final trend = _percentChange(recent, earlier);

    final labelStyle = AppType.caption(t).copyWith(fontSize: 10.5);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${AppFormat.compact(recent)} kg',
                      style: AppType.metric(t, size: 24),
                    ),
                    const SizedBox(height: 3),
                    Text('Last 4 weeks', style: AppType.caption(t)),
                  ],
                ),
              ),
              if (earlier > 0)
                DeltaBadge(delta: trend, percent: true, fontSize: 12),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 186,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (weeks.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: t.divider, strokeWidth: 1);
                  },
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
                      interval: interval,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            AppFormat.compact(value),
                            style: labelStyle,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: weeks.length <= 6
                          ? 1.0
                          : (weeks.length / 4).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= weeks.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            AppFormat.dayMonth(weeks[index].start),
                            style: labelStyle,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < weeks.length; i++)
                        FlSpot(i.toDouble(), weeks[i].volume),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.26,
                    preventCurveOverShooting: true,
                    gradient: t.primaryGradient,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: t.chartFillGradient,
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => t.elevated,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.round();
                        if (index < 0 || index >= weeks.length) return null;
                        final week = weeks[index];
                        return LineTooltipItem(
                          '${AppFormat.compact(week.volume)} kg\n'
                          'week of ${AppFormat.dayMonth(week.start)} · '
                          '${week.workouts} '
                          '${week.workouts == 1 ? 'session' : 'sessions'}',
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
}

/// ---------------------------------------------------------------------------
/// Streaks, the last seven days and training frequency.
/// ---------------------------------------------------------------------------
class _ConsistencyCard extends ConsumerWidget {
  final TrainingData data;

  const _ConsistencyCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final streak = data.streak;
    final perWeek = AnalyticsService.weeklyFrequency(data.sessions);

    return AppCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ConsistencyScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.local_fire_department_rounded,
                color: streak.current > 0 ? t.warning : t.textSecondary,
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
                      streak.current > 0
                          ? '${streak.current}-week streak'
                          : 'No active streak',
                      style: AppType.heading(t).copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${streak.thisWeek} '
                      '${streak.thisWeek == 1 ? 'session' : 'sessions'} '
                      'so far this week',
                      style: AppType.caption(t),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: t.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  value: '${streak.current}',
                  label: 'Current streak',
                ),
              ),
              _MiniDivider(color: t.divider),
              Expanded(
                child: _MiniMetric(
                  value: '${streak.longest}',
                  label: 'Longest streak',
                ),
              ),
              _MiniDivider(color: t.divider),
              Expanded(
                child: _MiniMetric(
                  value: AppFormat.weight(perWeek),
                  label: 'Sessions / week',
                ),
              ),
            ],
          ),
          Divider(height: AppSpacing.xxl, thickness: 1, color: t.divider),
          WeekStrip(
            days: data.lastSevenDays,
            labels: _lastSevenDayLabels(),
            dotSize: 30,
          ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppType.metric(t, size: 22)),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption(t).copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _MiniDivider extends StatelessWidget {
  final Color color;

  const _MiniDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: color,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Weekly sets per muscle group against the user's weekly set band.
/// ---------------------------------------------------------------------------
class _MuscleBalanceCard extends ConsumerWidget {
  /// The full balance list, highest weekly volume first.
  final List<MuscleBalance> balance;

  /// The band the bars are scored against. Passed down beside the balance it
  /// was computed from, so the caption, the shaded strip and the colours can
  /// never come from different reads of the goal.
  final TrainingGoals goals;

  const _MuscleBalanceCard({required this.balance, required this.goals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final trained = balance.where((m) => m.totalSets > 0).toList();
    final top = trained.length > 4 ? trained.sublist(0, 4) : trained;

    // The shaded strip has to sit fully inside the track, so the axis clears
    // the top of the band before it starts stretching for the tallest bar.
    // Both ends move with the user's goal, so a 3–6 band and a 25–35 one draw
    // the same way whichever of the two is the larger number.
    var axisMax = goals.setsMax * 1.2;
    for (final group in top) {
      axisMax = math.max(axisMax, group.setsPerWeek * 1.1);
    }

    return AppCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => MuscleGroupsScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.pie_chart_rounded,
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
                      'Weekly sets by muscle',
                      style: AppType.heading(t).copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Shaded band = the ${goals.bandLabel} sets/week target',
                      style: AppType.caption(t),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: t.textTertiary,
              ),
            ],
          ),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text(
                'None of your exercises are linked to a muscle group yet. '
                'Set the muscle group on an exercise and this fills in.',
                style: AppType.secondary(t),
              ),
            )
          else ...[
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < top.length; i++)
              FadeSlideIn(
                index: i,
                child: StatBar(
                  label: top[i].group,
                  value: top[i].setsPerWeek,
                  max: axisMax,
                  valueLabel: '${AppFormat.weight(top[i].setsPerWeek)}/wk',
                  color: _statusColor(t, top[i].status),
                  targetMin: goals.setsMin,
                  targetMax: goals.setsMax,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_rounded, size: 15, color: t.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_verdict(), style: AppType.caption(t)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _verdict() {
    final weakest = AnalyticsService.weakestGroups(balance, limit: 1);
    if (weakest.isEmpty) {
      return 'Every muscle group sits inside the ${goals.bandLabel} '
          'sets/week band. Nicely balanced.';
    }
    final group = weakest.first;
    if (group.status == VolumeStatus.high) {
      return '${group.group} is your outlier at '
          '${AppFormat.weight(group.setsPerWeek)} sets/week — above the '
          '${goals.bandLabel} band.';
    }
    return '${group.group} is your biggest gap at '
        '${AppFormat.weight(group.setsPerWeek)} sets/week. '
        'Aim for ${goals.weeklySetsMin} or more.';
  }

  Color _statusColor(AppColors t, VolumeStatus status) => switch (status) {
        VolumeStatus.none => t.textTertiary,
        VolumeStatus.low => t.warning,
        VolumeStatus.optimal => t.success,
        VolumeStatus.high => t.primary,
      };
}

/// ---------------------------------------------------------------------------
/// Links to the detailed screens.
/// ---------------------------------------------------------------------------
class _NavigationGroup extends StatelessWidget {
  const _NavigationGroup();

  @override
  Widget build(BuildContext context) {
    return AppTileGroup(
      children: [
        AppTile(
          bare: true,
          icon: Icons.emoji_events_rounded,
          title: 'Personal records',
          subtitle: 'Every all-time best, searchable',
          onTap: () => _open(context, (context) => const RecordsScreen()),
        ),
        AppTile(
          bare: true,
          icon: Icons.calendar_today_rounded,
          title: 'Consistency',
          subtitle: 'Your workout heatmap',
          onTap: () => _open(context, (context) => const ConsistencyScreen()),
        ),
        AppTile(
          bare: true,
          icon: Icons.show_chart_rounded,
          title: 'Exercise progression',
          subtitle: 'Weight and volume charts per lift',
          onTap: () => _open(context, (context) => ProgressionScreen()),
        ),
        AppTile(
          bare: true,
          icon: Icons.trending_up_rounded,
          title: '1RM tracker',
          subtitle: 'Estimated one-rep max over time',
          onTap: () => _open(context, (context) => const OneRMScreen()),
        ),
        AppTile(
          bare: true,
          icon: Icons.pie_chart_rounded,
          title: 'Muscle groups',
          subtitle: 'Distribution across your training',
          onTap: () => _open(context, (context) => MuscleGroupsScreen()),
        ),
        AppTile(
          bare: true,
          icon: Icons.bar_chart_rounded,
          title: 'Volume tracker',
          subtitle: 'Working sets per muscle group',
          onTap: () => _open(context, (context) => const VolumeTrackerScreen()),
        ),
      ],
    );
  }

  void _open(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
}

/// ---------------------------------------------------------------------------
/// Loading state — shaped like the real dashboard.
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
          Row(
            children: [
              Expanded(child: SkeletonCard(height: 126)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: SkeletonCard(height: 126)),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: SkeletonCard(height: 126)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: SkeletonCard(height: 126)),
            ],
          ),
          SizedBox(height: AppSpacing.xxl),
          SkeletonCard(height: 88),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 260),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 190),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Small helpers
/// ---------------------------------------------------------------------------

/// Percentage change between two periods, matching [PeriodSummary]'s own rule:
/// growing from nothing counts as +100% rather than infinity.
double _percentChange(num current, num previous) {
  if (previous == 0) return current == 0 ? 0 : 100;
  return ((current - previous) / previous) * 100;
}

double _sumVolume(List<TimeBucket> weeks, int start, int end) {
  var total = 0.0;
  for (var i = math.max(0, start); i < math.min(weeks.length, end); i++) {
    total += weeks[i].volume;
  }
  return total;
}

String _periodNoun(StatsPeriod period) => switch (period) {
      StatsPeriod.week => '7 days',
      StatsPeriod.month => '30 days',
      StatsPeriod.quarter => '90 days',
      StatsPeriod.year => 'year',
      StatsPeriod.all => 'period',
    };

/// Weekday initials for the last seven days, oldest first — the labels under
/// [WeekStrip], which uses the same ordering.
List<String> _lastSevenDayLabels({DateTime? now}) {
  final reference = now ?? DateTime.now();
  return [
    for (var i = 6; i >= 0; i--)
      AppFormat.weekdaysShort[
          reference.subtract(Duration(days: i)).weekday - 1],
  ];
}
