import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/stats_components.dart';
import '../widgets/ui/ui.dart';

/// ---------------------------------------------------------------------------
/// Consistency — the habit, not the lifting.
///
/// Four questions, in order of how often people ask them:
///   1. How long have I kept it up?       → the streak, as the headline, with
///      this week's count and the weekly average beside it
///   2. Did I train this week?            → the seven-day strip
///   3. What does the year look like?     → the heat map
///   4. Which days do I actually train?   → the weekday breakdown, which is
///      usually the part that surprises people.
///
/// Everything derives from the cached [trainingDataProvider] snapshot; the heat
/// map's day buckets are built locally with [AnalyticsService.dayOf] rather than
/// re-reading the session collection.
/// ---------------------------------------------------------------------------
class ConsistencyScreen extends ConsumerStatefulWidget {
  const ConsistencyScreen({super.key});

  @override
  ConsumerState<ConsistencyScreen> createState() => _ConsistencyScreenState();
}

/// The heat-map window. Kept from the previous screen's dropdown.
enum _Range {
  quarter(90, '3m', 'Last 3 months'),
  half(180, '6m', 'Last 6 months'),
  year(365, '1y', 'Last year'),
  all(null, 'All', 'All time');

  const _Range(this.days, this.label, this.longLabel);

  final int? days;
  final String label;
  final String longLabel;
}

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class _ConsistencyScreenState extends ConsumerState<ConsistencyScreen> {
  _Range _range = _Range.quarter;
  DateTime? _selectedDay;

  Future<void> _refresh() async {
    ref.invalidate(workoutSessionsProvider);
    ref.invalidate(exerciseMuscleMapProvider);
    await ref.read(trainingDataProvider.future);
  }

  Widget _rangeBar() => AppSegmented<_Range>(
        value: _range,
        segments: [
          for (final range in _Range.values)
            AppSegment(value: range, label: range.label),
        ],
        onChanged: (range) => setState(() {
          _range = range;
          _selectedDay = null;
        }),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trainingDataProvider);

    return async.when(
      loading: () => AppScaffold(
        title: 'Consistency',
        headerBottom: _rangeBar(),
        // Shaped like the page: headline, the week, then the calendar.
        children: const [
          SizedBox(height: AppSpacing.sm),
          SkeletonCard(height: 184),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 136),
          SizedBox(height: AppSpacing.xxl),
          SkeletonCard(height: 260),
        ],
      ),
      error: (error, stackTrace) => AppScaffold(
        title: 'Consistency',
        body: ErrorState(
          message: 'Could not load your training history.',
          onRetry: _refresh,
        ),
      ),
      data: (data) => _buildData(context, data),
    );
  }

  Widget _buildData(BuildContext context, TrainingData data) {
    if (data.sessions.isEmpty) {
      return AppScaffold(
        title: 'Consistency',
        onRefresh: _refresh,
        body: EmptyState(
          icon: Icons.calendar_month_rounded,
          title: 'No workouts logged yet',
          message: 'Finish your first session and your streaks, calendar and '
              'training days will start filling in here.',
          actionLabel: 'Back to statistics',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final now = DateTime.now();
    final today = AnalyticsService.dayOf(now);

    var oldest = data.sessions.first.date;
    for (final session in data.sessions) {
      if (session.date.isBefore(oldest)) oldest = session.date;
    }

    final windowStart = _range.days == null
        ? AnalyticsService.dayOf(oldest)
        : AnalyticsService.addDays(today, -(_range.days! - 1));

    final windowSessions = <WorkoutSession>[
      for (final session in data.sessions)
        if (!AnalyticsService.dayOf(session.date).isBefore(windowStart)) session,
    ];

    // day → sessions that day, the shape flutter_heatmap_calendar wants.
    final datasets = <DateTime, int>{};
    for (final session in windowSessions) {
      final day = AnalyticsService.dayOf(session.date);
      datasets[day] = (datasets[day] ?? 0) + 1;
    }

    final streak = data.streak;
    final goal = data.goals.sessionsPerWeek;
    final frequency = AnalyticsService.weeklyFrequency(data.sessions);
    final weekdayCounts = AnalyticsService.weekdayDistribution(windowSessions);

    final weekLabels = <String>[
      for (var i = 6; i >= 0; i--)
        AppFormat.weekdaysShort[AnalyticsService.addDays(today, -i).weekday - 1],
    ];

    return AppScaffold(
      title: 'Consistency',
      subtitle: '${_range.longLabel} · ${windowSessions.length} '
          '${windowSessions.length == 1 ? 'session' : 'sessions'}',
      headerBottom: _rangeBar(),
      onRefresh: _refresh,
      children: [
        const SizedBox(height: AppSpacing.sm),
        FadeSlideIn(
          child: StatsHeadlineCard(
            value: streak.current.toDouble(),
            unit: 'week streak',
            icon: Icons.local_fire_department_rounded,
            caption: goal > 1
                ? 'Weeks with at least $goal sessions, back to back'
                : 'Weeks with a session, back to back',
            metrics: [
              HeadlineMetric(
                label: 'Longest',
                value: '${streak.longest}',
                unit: streak.longest == 1 ? 'week' : 'weeks',
              ),
              HeadlineMetric(
                label: 'This week',
                // A weekly goal turns the count into progress, so show what
                // it is being counted toward rather than just the number.
                value: goal > 1
                    ? '${streak.thisWeek}/$goal'
                    : '${streak.thisWeek}',
                unit: goal > 1
                    ? null
                    : streak.thisWeek == 1
                        ? 'session'
                        : 'sessions',
              ),
              HeadlineMetric(
                label: 'Per week',
                value: frequency.toStringAsFixed(1),
                unit: 'avg',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(
          index: 1,
          child: _WeekCard(days: data.lastSevenDays, labels: weekLabels),
        ),
        const SectionHeader(title: 'Training calendar'),
        FadeSlideIn(
          key: ValueKey('heatmap-${_range.name}'),
          child: _HeatmapCard(
            datasets: datasets,
            startDate: windowStart,
            endDate: today,
            selected: _selectedDay,
            onSelect: (day) {
              HapticStrength.selection.fire();
              setState(() => _selectedDay = AnalyticsService.dayOf(day));
            },
          ),
        ),
        const SectionHeader(title: 'Training days'),
        FadeSlideIn(
          key: ValueKey('weekdays-${_range.name}'),
          child: _WeekdayBreakdown(counts: weekdayCounts),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// The last seven days
/// ---------------------------------------------------------------------------

class _WeekCard extends ConsumerWidget {
  /// Oldest first, today last — exactly what `TrainingData.lastSevenDays` gives.
  final List<bool> days;
  final List<String> labels;

  const _WeekCard({required this.days, required this.labels});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final trained = days.where((d) => d).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Overline('Last 7 days', padding: EdgeInsets.zero)),
              AppBadge(
                label: '$trained of 7 days',
                // Green once it is a solid week; otherwise just a count.
                color: trained >= 3 ? t.success : t.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          WeekStrip(days: days, labels: labels),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// The heat map
/// ---------------------------------------------------------------------------

class _HeatmapCard extends ConsumerWidget {
  final Map<DateTime, int> datasets;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  const _HeatmapCard({
    required this.datasets,
    required this.startDate,
    required this.endDate,
    required this.selected,
    required this.onSelect,
  });

  /// The package's weekday-label column ("Mon", "Wed"…) plus its margins.
  static const double _weekLabelWidth = 26;
  static const double _cellMargin = 2;
  static const double _minCell = 14;
  static const double _maxCell = 22;
  static const double _scrollCell = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    // Threshold → colour. One hue, four steps, so a busy day reads darker.
    final colorsets = <int, Color>{
      1: t.primary.withValues(alpha: t.isDark ? 0.30 : 0.26),
      2: t.primary.withValues(alpha: t.isDark ? 0.55 : 0.50),
      3: t.primary.withValues(alpha: t.isDark ? 0.78 : 0.75),
      4: t.primary,
    };

    final selectedCount = selected == null ? 0 : (datasets[selected] ?? 0);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Columns the package draws: one per week, Sunday-first.
              final days = endDate.difference(startDate).inDays;
              final weeks = (days + startDate.weekday % 7) ~/ 7 + 1;
              final fitted =
                  (constraints.maxWidth - _weekLabelWidth) / weeks -
                      2 * _cellMargin;

              // When every week fits at a readable size, show the whole range
              // with its weekday labels. Otherwise scroll (newest first) and
              // fade the far edge so the cut-off column reads as "more".
              final fits = fitted >= _minCell;
              final heatmap = HeatMap(
                datasets: datasets,
                colorMode: ColorMode.color,
                showText: false,
                scrollable: !fits,
                colorsets: colorsets,
                onClick: (day) => onSelect(day),
                startDate: startDate,
                endDate: endDate,
                size: fits ? math.min(fitted, _maxCell) : _scrollCell,
                margin: const EdgeInsets.all(_cellMargin),
                borderRadius: 4,
                textColor: t.textSecondary,
                fontSize: 10.5,
                defaultColor: t.surface,
                showColorTip: false,
              );
              if (fits) return heatmap;
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0x00000000), Color(0xFF000000)],
                  stops: [0.0, 0.08],
                ).createShader(bounds),
                child: heatmap,
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text('Less', style: AppType.caption(t)),
              const SizedBox(width: AppSpacing.sm),
              _LegendSwatch(color: t.surface),
              for (final step in colorsets.values) _LegendSwatch(color: step),
              const SizedBox(width: AppSpacing.sm),
              Text('More', style: AppType.caption(t)),
              const Spacer(),
              Text(
                'Tap a day',
                style: AppType.caption(t).copyWith(color: t.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, thickness: 1, color: t.divider),
          const SizedBox(height: AppSpacing.sm),
          if (selected != null)
            MetricRow(
              label: '${_weekdayNames[selected!.weekday - 1]}, '
                  '${AppFormat.dayMonth(selected!)}',
              value: selectedCount == 0
                  ? 'Rest day'
                  : '$selectedCount ${selectedCount == 1 ? 'session' : 'sessions'}',
              valueColor: selectedCount == 0 ? t.textSecondary : t.primary,
            ),
          MetricRow(label: 'Days trained', value: '${datasets.length}'),
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;

  const _LegendSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Weekday distribution
/// ---------------------------------------------------------------------------

/// Which days of the week the training actually lands on, as seven columns
/// with the busiest day in the accent. Most people are convinced they are
/// even across the week and are not.
class _WeekdayBreakdown extends ConsumerWidget {
  /// 1 = Monday … 7 = Sunday, straight from
  /// [AnalyticsService.weekdayDistribution].
  final Map<int, int> counts;

  const _WeekdayBreakdown({required this.counts});

  static const double _plotHeight = 112;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final values = <int>[for (var day = 1; day <= 7; day++) counts[day] ?? 0];
    final total = values.fold<int>(0, (sum, v) => sum + v);
    final maxCount = values.reduce(math.max);

    var busiest = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[busiest]) busiest = i;
    }
    final share = total == 0 ? 0.0 : values[busiest] / total * 100;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (total > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _weekdayNames[busiest],
                      style: AppType.heading(t),
                    ),
                    TextSpan(
                      text: ' is your day · '
                          '${share.toStringAsFixed(share < 10 ? 1 : 0)}% of '
                          'sessions',
                      style: AppType.secondary(t),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: FadeSlideIn(
                    index: i,
                    child: _DayColumn(
                      label: AppFormat.weekdaysShort[i],
                      count: values[i],
                      fraction: maxCount == 0 ? 0 : values[i] / maxCount,
                      height: _plotHeight,
                      highlight: total > 0 && i == busiest,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends ConsumerWidget {
  final String label;
  final int count;
  final double fraction;
  final double height;
  final bool highlight;

  const _DayColumn({
    required this.label,
    required this.count,
    required this.fraction,
    required this.height,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = highlight
        ? t.primary
        : t.textSecondary.withValues(alpha: t.isDark ? 0.42 : 0.32);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count == 0 ? '' : '$count',
          style: AppType.mono(t, size: 12.5).copyWith(
            color: highlight ? t.text : t.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction),
              duration: AppMotion.lazy,
              curve: AppMotion.enter,
              builder: (context, f, _) => Container(
                width: 22,
                // A zero day keeps a stub, so the empty days still line up.
                height: count == 0 ? 4 : math.max(6, height * f),
                decoration: BoxDecoration(
                  color: count == 0 ? t.surface : tone,
                  borderRadius: BorderRadius.circular(AppRadius.xs - 2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: AppType.caption(t).copyWith(
            color: highlight ? t.text : t.textSecondary,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
