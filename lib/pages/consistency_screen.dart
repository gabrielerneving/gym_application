import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/ui/ui.dart';

/// ---------------------------------------------------------------------------
/// Consistency — the habit, not the lifting.
///
/// Four questions, in order of how often people ask them:
///   1. Did I train this week?            → the seven-day strip
///   2. How long have I kept it up?       → streaks and weekly frequency
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
        children: const [
          SizedBox(height: AppSpacing.lg),
          SkeletonCard(height: 120),
          SizedBox(height: AppSpacing.xl),
          SkeletonCard(height: 150),
          SizedBox(height: AppSpacing.xl),
          SkeletonCard(height: 220),
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
        : today.subtract(Duration(days: _range.days! - 1));

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
    final frequency = AnalyticsService.weeklyFrequency(data.sessions);
    final weekdayCounts = AnalyticsService.weekdayDistribution(windowSessions);

    final weekLabels = <String>[
      for (var i = 6; i >= 0; i--)
        AppFormat.weekdaysShort[
            today.subtract(Duration(days: i)).weekday - 1],
    ];

    return AppScaffold(
      title: 'Consistency',
      subtitle: '${_range.longLabel} · ${windowSessions.length} '
          '${windowSessions.length == 1 ? 'session' : 'sessions'}',
      headerBottom: _rangeBar(),
      onRefresh: _refresh,
      children: [
        const SizedBox(height: AppSpacing.lg),
        FadeSlideIn(
          child: _WeekCard(days: data.lastSevenDays, labels: weekLabels),
        ),
        const SizedBox(height: AppSpacing.xxl),
        StatGrid(
          children: [
            StatTile(
              label: 'Current streak',
              value: streak.current.toDouble(),
              unit: streak.current == 1 ? 'week' : 'weeks',
              icon: Icons.local_fire_department_rounded,
              highlight: true,
            ),
            StatTile(
              label: 'Longest streak',
              value: streak.longest.toDouble(),
              unit: streak.longest == 1 ? 'week' : 'weeks',
              icon: Icons.emoji_events_rounded,
            ),
            StatTile(
              label: 'This week',
              value: streak.thisWeek.toDouble(),
              unit: streak.thisWeek == 1 ? 'session' : 'sessions',
              icon: Icons.event_available_rounded,
            ),
            StatTile(
              label: 'Average per week',
              value: frequency,
              decimals: 1,
              unit: 'sessions',
              icon: Icons.timeline_rounded,
              sparkline: [
                for (final bucket in data.weeklyVolume)
                  bucket.workouts.toDouble(),
              ],
            ),
          ],
        ),
        const SectionHeader(
          title: 'Training calendar',
          subtitle: 'Every day you showed up',
        ),
        FadeSlideIn(
          key: ValueKey('heatmap-${_range.name}'),
          child: _HeatmapCard(
            datasets: datasets,
            startDate: windowStart,
            endDate: today,
            selected: _selectedDay,
            sessions: windowSessions.length,
            onSelect: (day) {
              HapticStrength.selection.fire();
              setState(() => _selectedDay = AnalyticsService.dayOf(day));
            },
          ),
        ),
        const SectionHeader(
          title: 'Which days you train',
          subtitle: 'Sessions by weekday in this window',
        ),
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

    final String message;
    if (trained == 0) {
      message = 'No sessions in the last seven days.';
    } else if (days.isNotEmpty && days.last) {
      message = 'You trained $trained of the last 7 days, including today.';
    } else {
      message = 'You trained $trained of the last 7 days.';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Overline('Last 7 days', padding: EdgeInsets.zero)),
              AppBadge(
                label: '$trained / 7',
                color: trained >= 3 ? t.success : t.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          WeekStrip(days: days, labels: labels),
          const SizedBox(height: AppSpacing.lg),
          Text(message, style: AppType.secondary(t)),
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
  final int sessions;
  final ValueChanged<DateTime> onSelect;

  const _HeatmapCard({
    required this.datasets,
    required this.startDate,
    required this.endDate,
    required this.selected,
    required this.sessions,
    required this.onSelect,
  });

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
          HeatMap(
            datasets: datasets,
            colorMode: ColorMode.color,
            showText: false,
            scrollable: true,
            colorsets: colorsets,
            onClick: (day) => onSelect(day),
            startDate: startDate,
            endDate: endDate,
            size: 20,
            textColor: t.textSecondary,
            fontSize: 11,
            defaultColor: t.surface,
            showColorTip: false,
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
              icon: Icons.event_rounded,
              label: '${_weekdayNames[selected!.weekday - 1]}, '
                  '${AppFormat.dayMonth(selected!)}',
              value: selectedCount == 0
                  ? 'Rest day'
                  : '$selectedCount ${selectedCount == 1 ? 'session' : 'sessions'}',
              valueColor: selectedCount == 0 ? t.textSecondary : t.primary,
            ),
          MetricRow(
            icon: Icons.fitness_center_rounded,
            label: 'Sessions in this window',
            value: '$sessions',
          ),
          MetricRow(
            icon: Icons.today_rounded,
            label: 'Days trained',
            value: '${datasets.length}',
          ),
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

/// Which days of the week the training actually lands on. Most people are
/// convinced they are even across the week and are not.
class _WeekdayBreakdown extends ConsumerWidget {
  /// 1 = Monday … 7 = Sunday, straight from
  /// [AnalyticsService.weekdayDistribution].
  final Map<int, int> counts;

  const _WeekdayBreakdown({required this.counts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final values = <int>[for (var day = 1; day <= 7; day++) counts[day] ?? 0];
    final total = values.fold<int>(0, (sum, v) => sum + v);
    final maxCount = values.reduce(math.max);

    var busiest = 0;
    var quietest = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[busiest]) busiest = i;
      if (values[i] < values[quietest]) quietest = i;
    }

    final String verdict;
    if (total == 0) {
      verdict = 'No sessions in this window yet.';
    } else if (values[busiest] == values[quietest]) {
      verdict = 'Your sessions are spread perfectly evenly across the week — '
          '${values[busiest]} on every day.';
    } else {
      final share = (values[busiest] / total) * 100;
      final busiestLine = '${_weekdayNames[busiest]} is your day — '
          '${share.toStringAsFixed(share < 10 ? 1 : 0)}% of your sessions '
          'land there.';
      final quietLine = values[quietest] == 0
          ? ' You have never trained on a ${_weekdayNames[quietest]} in this '
              'window.'
          : ' ${_weekdayNames[quietest]} is your lightest day with '
              '${values[quietest]}.';
      verdict = busiestLine + quietLine;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: Icons.calendar_view_week_rounded),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(verdict, style: AppType.body(t)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < values.length; i++)
            FadeSlideIn(
              index: i,
              child: StatBar(
                label: _weekdayNames[i],
                value: values[i].toDouble(),
                max: maxCount == 0 ? 1.0 : maxCount.toDouble(),
                valueLabel: _valueLabel(values[i], total),
                color: total > 0 && i == busiest ? t.primary : t.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  String _valueLabel(int value, int total) {
    if (value == 0) return '—';
    final share = (value / total) * 100;
    return '$value  ·  ${share.toStringAsFixed(share < 10 ? 1 : 0)}%';
  }
}
