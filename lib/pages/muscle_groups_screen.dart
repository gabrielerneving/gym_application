import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_session_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/muscle_bar_chart_widget.dart';
import '../widgets/muscle_radar_chart_widget.dart';
import '../widgets/training_goal_sheets.dart';
import '../widgets/ui/ui.dart';

/// ---------------------------------------------------------------------------
/// Muscle groups — where the work actually went.
///
/// Two views over the same window:
///   * **Balance**   — the radar plus a plain-language verdict on which groups
///                     are over- and under-represented against the user's
///                     weekly set band.
///   * **Breakdown** — the numbers: a bar per group and a target-banded
///                     [StatBar] list sorted by weekly volume.
///
/// Everything is derived from the cached [trainingDataProvider] snapshot via
/// [AnalyticsService]; nothing on this screen touches Firestore directly. The
/// band both views score against is the [TrainingGoals] carried on that same
/// snapshot, passed down rather than re-read, so a shaded strip and the caption
/// under it can never describe different numbers.
/// ---------------------------------------------------------------------------
class MuscleGroupsScreen extends ConsumerStatefulWidget {
  const MuscleGroupsScreen({super.key});

  @override
  ConsumerState<MuscleGroupsScreen> createState() => _MuscleGroupsScreenState();
}

enum _MuscleView { balance, breakdown }

class _MuscleGroupsScreenState extends ConsumerState<MuscleGroupsScreen> {
  _MuscleView _view = _MuscleView.balance;

  Future<void> _refresh() async {
    ref.invalidate(workoutSessionsProvider);
    ref.invalidate(exerciseMuscleMapProvider);
    await ref.read(trainingDataProvider.future);
  }

  void _setPeriod(StatsPeriod period) {
    ref.read(statsPeriodProvider.notifier).state = period;
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(statsPeriodProvider);
    final async = ref.watch(trainingDataProvider);

    return async.when(
      loading: () => AppScaffold(
        title: 'Muscle groups',
        headerBottom: _PeriodBar(value: period, onChanged: _setPeriod),
        children: const [
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 42, radius: AppRadius.pill),
          SizedBox(height: AppSpacing.xl),
          SkeletonCard(height: 300),
          SizedBox(height: AppSpacing.xl),
          SkeletonCard(height: 180),
        ],
      ),
      error: (error, stackTrace) => AppScaffold(
        title: 'Muscle groups',
        body: ErrorState(
          message: 'Could not load your training history.',
          onRetry: _refresh,
        ),
      ),
      data: (data) => _buildData(context, data, period),
    );
  }

  Widget _buildData(
    BuildContext context,
    TrainingData data,
    StatsPeriod period,
  ) {
    if (data.sessions.isEmpty) {
      return AppScaffold(
        title: 'Muscle groups',
        onRefresh: _refresh,
        body: EmptyState(
          icon: Icons.donut_large_rounded,
          title: 'No training logged yet',
          message:
              'Finish a workout and this screen will show how your sets are '
              'spread across the muscle groups.',
          actionLabel: 'Back to statistics',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final now = DateTime.now();
    final weeks = _weeksFor(period, data.sessions, now);

    // The exact window AnalyticsService.muscleBalance averages over, rebuilt
    // here so the counts, the shares and the per-week rates all describe the
    // same slice of time.
    final windowStart = AnalyticsService.weekStart(now)
        .subtract(Duration(days: 7 * (weeks - 1)));
    final range = DateRange(windowStart, now);

    final counts = AnalyticsService.muscleGroupSets(
      data.sessions,
      data.exerciseToMuscle,
      range: range,
    );
    final balance = AnalyticsService.muscleBalance(
      data.sessions,
      data.exerciseToMuscle,
      weeks: weeks,
      now: now,
      goals: data.goals,
    );

    final groupCounts = <String, int>{
      for (final group in AnalyticsService.defaultMuscleGroups)
        group: counts[group] ?? 0,
    };
    // Exercises missing from the master-exercise map land here. Never dropped.
    final uncategorised = counts['Other'] ?? 0;
    final categorised = groupCounts.values.fold<int>(0, (sum, v) => sum + v);
    final total = categorised + uncategorised;
    final windowLabel = _windowLabel(period, weeks);

    if (total == 0) {
      return AppScaffold(
        title: 'Muscle groups',
        subtitle: windowLabel,
        headerBottom: _PeriodBar(value: period, onChanged: _setPeriod),
        onRefresh: _refresh,
        body: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Nothing in this window',
          message: 'No working sets were logged in this window '
              '($windowLabel). Try a longer period.',
          actionLabel:
              period == StatsPeriod.all ? 'Back to statistics' : 'Show all time',
          onAction: period == StatsPeriod.all
              ? () => Navigator.of(context).maybePop()
              : () => _setPeriod(StatsPeriod.all),
        ),
      );
    }

    return AppScaffold(
      title: 'Muscle groups',
      subtitle: '$windowLabel · $total ${total == 1 ? 'set' : 'sets'}',
      headerBottom: _PeriodBar(value: period, onChanged: _setPeriod),
      onRefresh: _refresh,
      children: _sections(
        balance: balance,
        goals: data.goals,
        groupCounts: groupCounts,
        categorised: categorised,
        uncategorised: uncategorised,
        total: total,
        windowLabel: windowLabel,
      ),
    );
  }

  List<Widget> _sections({
    required List<MuscleBalance> balance,
    required TrainingGoals goals,
    required Map<String, int> groupCounts,
    required int categorised,
    required int uncategorised,
    required int total,
    required String windowLabel,
  }) {
    final isBalance = _view == _MuscleView.balance;
    final view = _view.name;

    return [
      const SizedBox(height: AppSpacing.lg),
      FadeSlideIn(
        key: const ValueKey('switcher'),
        child: _ViewSwitcher(
          value: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),

      if (isBalance) ...[
        FadeSlideIn(
          key: ValueKey('$view-chart'),
          index: 1,
          child: _RadarCard(groupCounts: groupCounts, totalSets: categorised),
        ),
        SectionHeader(
          title: 'How balanced are you?',
          subtitle:
              'Weekly sets against the ${goals.bandLabel} band · $windowLabel',
        ),
        FadeSlideIn(
          key: ValueKey('$view-verdict'),
          index: 2,
          child: _BalanceVerdict(balance: balance, goals: goals),
        ),
      ] else ...[
        FadeSlideIn(
          key: ValueKey('$view-chart'),
          index: 1,
          child: _BarCard(groupCounts: groupCounts, totalSets: categorised),
        ),
        SectionHeader(
          title: 'Sets per week',
          subtitle: 'Sorted by volume · $windowLabel',
        ),
        FadeSlideIn(
          key: ValueKey('$view-list'),
          index: 2,
          child: _BreakdownList(
            balance: balance,
            goals: goals,
            totalSets: categorised,
          ),
        ),
      ],

      if (uncategorised > 0) ...[
        const SizedBox(height: AppSpacing.lg),
        FadeSlideIn(
          key: ValueKey('$view-note'),
          index: 3,
          child: _UncategorisedNote(sets: uncategorised, total: total),
        ),
      ],
    ];
  }

  /// How many weeks the selected period covers. Used both for the averaging
  /// window and for the honest label above the numbers.
  int _weeksFor(
    StatsPeriod period,
    List<WorkoutSession> sessions,
    DateTime now,
  ) {
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
        if (sessions.isEmpty) return 1;
        var oldest = sessions.first.date;
        for (final session in sessions) {
          if (session.date.isBefore(oldest)) oldest = session.date;
        }
        final firstWeek = AnalyticsService.weekStart(oldest);
        final thisWeek = AnalyticsService.weekStart(now);
        // Hours ÷ 24 rather than inDays so daylight-saving shifts do not eat
        // a week off the count.
        final days = (thisWeek.difference(firstWeek).inHours / 24).round();
        return math.max(1, days ~/ 7 + 1);
    }
  }

  String _windowLabel(StatsPeriod period, int weeks) {
    if (period == StatsPeriod.all) {
      return 'All time · $weeks ${weeks == 1 ? 'week' : 'weeks'}';
    }
    if (weeks == 1) return 'This week so far';
    return 'Last $weeks weeks';
  }
}

/// low → warning, optimal → success, high → primary, untrained → muted.
Color _statusColor(AppColors t, VolumeStatus status) => switch (status) {
      VolumeStatus.none => t.textSecondary,
      VolumeStatus.low => t.warning,
      VolumeStatus.optimal => t.success,
      VolumeStatus.high => t.primary,
    };

String _perWeek(double value) => '${AppFormat.weight(value)}/wk';

/// ---------------------------------------------------------------------------
/// Controls
/// ---------------------------------------------------------------------------

class _PeriodBar extends StatelessWidget {
  final StatsPeriod value;
  final ValueChanged<StatsPeriod> onChanged;

  const _PeriodBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppSegmented<StatsPeriod>(
      value: value,
      segments: [
        for (final period in StatsPeriod.values)
          AppSegment(value: period, label: period.label),
      ],
      onChanged: onChanged,
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  final _MuscleView value;
  final ValueChanged<_MuscleView> onChanged;

  const _ViewSwitcher({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppSegmented<_MuscleView>(
      value: value,
      segments: const [
        AppSegment(
          value: _MuscleView.balance,
          label: 'Balance',
          icon: Icons.radar_rounded,
        ),
        AppSegment(
          value: _MuscleView.breakdown,
          label: 'Breakdown',
          icon: Icons.bar_chart_rounded,
        ),
      ],
      onChanged: onChanged,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Balance view
/// ---------------------------------------------------------------------------

class _RadarCard extends ConsumerWidget {
  final Map<String, int> groupCounts;
  final int totalSets;

  const _RadarCard({required this.groupCounts, required this.totalSets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Distribution', style: AppType.heading(t)),
                ),
                AppBadge(
                  label: '$totalSets sets',
                  icon: Icons.fitness_center_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 300,
            child: MuscleRadarChartWidget(muscleGroupCounts: groupCounts),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The outer ring is your most-trained group. Numbers are working '
            'sets in this window.',
            textAlign: TextAlign.center,
            style: AppType.caption(t),
          ),
        ],
      ),
    );
  }
}

/// The plain-language answer to "am I lopsided?".
class _BalanceVerdict extends ConsumerWidget {
  final List<MuscleBalance> balance;
  final TrainingGoals goals;

  const _BalanceVerdict({required this.balance, required this.goals});

  static const List<VolumeStatus> _order = [
    VolumeStatus.high,
    VolumeStatus.optimal,
    VolumeStatus.low,
    VolumeStatus.none,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    // muscleBalance comes back sorted by weekly volume, highest first.
    final trained = balance.where((b) => b.totalSets > 0).toList();
    final onTarget =
        balance.where((b) => b.status == VolumeStatus.optimal).length;

    final buckets = <VolumeStatus, List<MuscleBalance>>{};
    for (final entry in balance) {
      buckets.putIfAbsent(entry.status, () => <MuscleBalance>[]).add(entry);
    }

    final String headline;
    final String detail;
    if (trained.isEmpty) {
      headline = 'Nothing categorised in this window';
      detail = 'Log a few exercises from your library and the balance shows up '
          'here.';
    } else {
      headline = '$onTarget of ${balance.length} groups sit inside '
          '${goals.bandSentence}';
      if (trained.length == 1) {
        detail = '${trained.first.group} is the only group you trained, at '
            '${_perWeek(trained.first.setsPerWeek)}.';
      } else {
        detail = '${trained.first.group} leads at '
            '${_perWeek(trained.first.setsPerWeek)}; ${trained.last.group} '
            'trails at ${_perWeek(trained.last.setsPerWeek)}.';
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: Icons.insights_rounded,
                color: onTarget >= balance.length - 2 ? t.success : t.primary,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(headline, style: AppType.heading(t)),
                    const SizedBox(height: 4),
                    Text(detail, style: AppType.secondary(t)),
                  ],
                ),
              ),
            ],
          ),
          for (final status in _order)
            if (buckets[status] != null && buckets[status]!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              _StatusBlock(items: buckets[status]!, status: status),
            ],
        ],
      ),
    );
  }
}

/// One "Above target" / "Below target" / … group of badges.
class _StatusBlock extends ConsumerWidget {
  final List<MuscleBalance> items;
  final VolumeStatus status;

  const _StatusBlock({required this.items, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = _statusColor(t, status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Straight from MuscleBalance.statusLabel so the wording matches
            // the rest of the app.
            Text(items.first.statusLabel, style: AppType.overline(t)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in items)
              AppBadge(
                label: status == VolumeStatus.none
                    ? item.group
                    : '${item.group} · ${_perWeek(item.setsPerWeek)}',
                color: tone,
              ),
          ],
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Breakdown view
/// ---------------------------------------------------------------------------

class _BarCard extends ConsumerWidget {
  final Map<String, int> groupCounts;
  final int totalSets;

  const _BarCard({required this.groupCounts, required this.totalSets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Working sets', style: AppType.heading(t)),
                ),
                AppBadge(
                  label: '$totalSets sets',
                  icon: Icons.fitness_center_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 240,
            child: MuscleBarChartWidget(muscleGroupCounts: groupCounts),
          ),
        ],
      ),
    );
  }
}

/// Every group as a target-banded bar, biggest first.
class _BreakdownList extends ConsumerWidget {
  final List<MuscleBalance> balance;
  final TrainingGoals goals;
  final int totalSets;

  const _BreakdownList({
    required this.balance,
    required this.goals,
    required this.totalSets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final maxPerWeek = balance.isEmpty
        ? 0.0
        : balance.map((b) => b.setsPerWeek).reduce(math.max);
    // Whichever reaches higher sets the scale: the whole band has to stay in
    // the track when every group is far below it, and every bar has to when
    // the user has set a band low enough to be cleared.
    final barMax = math.max(maxPerWeek * 1.08, goals.setsMax * 1.2);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < balance.length; i++)
            FadeSlideIn(
              index: i,
              child: StatBar(
                label: _label(balance[i]),
                value: balance[i].setsPerWeek,
                max: barMax,
                valueLabel: _perWeek(balance[i].setsPerWeek),
                color: _statusColor(t, balance[i].status),
                targetMin: goals.setsMin,
                targetMax: goals.setsMax,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, thickness: 1, color: t.divider),
          const SizedBox(height: AppSpacing.md),
          // Tappable: this legend is where the band is most likely to strike
          // someone as wrong for them, which makes it the right place to be
          // able to change it rather than going hunting through Settings.
          Pressable(
            onTap: () => TrainingGoalSheets.weeklySetBand(context, ref),
            scale: 0.99,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.textSecondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    // The default band is the one from the literature and can be
                    // sold as such; a band the user chose is theirs, and saying
                    // otherwise would put words in the research's mouth.
                    goals.isDefault
                        ? 'The shaded band is ${goals.bandLabel} working sets a '
                            'week — the range most lifters grow on. Tap to '
                            'change it.'
                        : 'The shaded band is ${goals.bandLabel} working sets a '
                            'week — the goal you set for yourself.',
                    style: AppType.caption(t),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.tune_rounded, size: 16, color: t.textTertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(MuscleBalance item) {
    if (totalSets <= 0 || item.totalSets == 0) return item.group;
    final share = (item.totalSets / totalSets) * 100;
    return '${item.group}  ·  ${share.toStringAsFixed(share < 10 ? 1 : 0)}%';
  }
}

/// ---------------------------------------------------------------------------
/// Honesty note
/// ---------------------------------------------------------------------------

/// [AnalyticsService.muscleGroupSets] files exercises that are missing from the
/// master-exercise library under "Other". Rather than quietly dropping them,
/// say so — otherwise the percentages look wrong to anyone who counts.
class _UncategorisedNote extends ConsumerWidget {
  final int sets;
  final int total;

  const _UncategorisedNote({required this.sets, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final share = total <= 0 ? 0.0 : (sets / total) * 100;

    return AppCard(
      inset: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline_rounded, size: 19, color: t.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$sets ${sets == 1 ? 'set is' : 'sets are'} uncategorised',
                  style: AppType.body(t).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${share.toStringAsFixed(share < 10 ? 1 : 0)}% of your work '
                  'came from exercises that are not in your exercise library, '
                  'so they are counted as "Other" and left out of the charts '
                  'above.',
                  style: AppType.secondary(t),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
