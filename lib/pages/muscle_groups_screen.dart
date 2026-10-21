import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/muscle_radar_chart_widget.dart';
import '../widgets/stats_components.dart';
import '../widgets/training_goal_sheets.dart';
import '../widgets/ui/ui.dart';

/// ---------------------------------------------------------------------------
/// Muscle groups — where the work actually went.
///
/// One scroll, three answers: the radar for the *shape* of the training, a
/// bar per group for the *numbers* against the user's weekly set goal (the
/// goal drawn as two marks on the track), and the groups with room to grow,
/// with how much.
///
/// Everything is derived from the cached [trainingDataProvider] snapshot over
/// the shared period. Counts and per-week rates come from the same window, and
/// the band is the [TrainingGoals] carried on that snapshot, so a shaded strip
/// and the caption under it can never describe different numbers.
/// ---------------------------------------------------------------------------
class MuscleGroupsScreen extends ConsumerStatefulWidget {
  const MuscleGroupsScreen({super.key});

  @override
  ConsumerState<MuscleGroupsScreen> createState() => _MuscleGroupsScreenState();
}

class _MuscleGroupsScreenState extends ConsumerState<MuscleGroupsScreen> {
  static const String _title = 'Muscle groups';

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
        title: _title,
        headerBottom: _PeriodBar(value: period, onChanged: _setPeriod),
        children: const [
          SizedBox(height: AppSpacing.sm),
          SkeletonCard(height: 320),
          SizedBox(height: AppSpacing.xxl),
          SkeletonCard(height: 420),
        ],
      ),
      error: (error, stackTrace) => AppScaffold(
        title: _title,
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
        title: _title,
        onRefresh: _refresh,
        body: EmptyState(
          icon: Icons.donut_large_rounded,
          title: 'No training logged yet',
          message: 'Finish a workout and this screen shows how your sets are '
              'spread across the muscle groups.',
          actionLabel: 'Back to statistics',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final counts = data.muscleSetsFor(period);
    final balance = data.muscleBalanceFor(period);

    final groupCounts = <String, int>{
      for (final group in AnalyticsService.defaultMuscleGroups)
        group: counts[group] ?? 0,
    };
    // Exercises missing from the master-exercise map land here. Never dropped.
    final uncategorised = counts['Other'] ?? 0;
    final categorised = groupCounts.values.fold<int>(0, (sum, v) => sum + v);
    final total = categorised + uncategorised;

    if (total == 0) {
      return AppScaffold(
        title: _title,
        subtitle: period.longLabel,
        headerBottom: _PeriodBar(value: period, onChanged: _setPeriod),
        onRefresh: _refresh,
        body: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Nothing in this window',
          message: 'No working sets were logged in the '
              '${period.longLabel.toLowerCase()}. Try a longer period.',
          actionLabel:
              period == StatsPeriod.all ? 'Back to statistics' : 'Show all time',
          onAction: period == StatsPeriod.all
              ? () => Navigator.of(context).maybePop()
              : () => _setPeriod(StatsPeriod.all),
        ),
      );
    }

    final goals = data.goals;
    final summary = MuscleBalanceSummary.of(balance, goals);
    final lagging = AnalyticsService.weakestGroups(balance, limit: 4);

    return AppScaffold(
      title: _title,
      subtitle: '${period.longLabel} · $total ${total == 1 ? 'set' : 'sets'}',
      headerBottom: _PeriodBar(value: period, onChanged: _setPeriod),
      onRefresh: _refresh,
      children: [
        const SizedBox(height: AppSpacing.sm),
        FadeSlideIn(child: _RadarCard(groupCounts: groupCounts)),
        SectionHeader(title: 'Sets per week', subtitle: summary.title),
        FadeSlideIn(
          index: 1,
          child: _BreakdownList(balance: balance, goals: goals),
        ),
        if (categorised > 0 && lagging.isNotEmpty) ...[
          const SectionHeader(
            title: 'Room to grow',
            subtitle: 'Weekly sets to reach the bottom of your target',
          ),
          FadeSlideIn(index: 2, child: _AddList(lagging: lagging)),
        ],
        if (uncategorised > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 3,
            child: _UncategorisedNote(sets: uncategorised, total: total),
          ),
        ],
      ],
    );
  }
}

String _perWeek(double value) => '${AppFormat.weight(value)}/wk';

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

/// The shape of the training. Axis titles carry the set counts; the rings are
/// relative to the most-trained group.
class _RadarCard extends ConsumerWidget {
  final Map<String, int> groupCounts;

  const _RadarCard({required this.groupCounts});

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
          // The axis titles sit outside the rings; the vertical padding gives
          // the top and bottom ones room so they never meet the caption.
          SizedBox(
            height: 320,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: MuscleRadarChartWidget(muscleGroupCounts: groupCounts),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Working sets per group, scaled to your most-trained one',
            textAlign: TextAlign.center,
            style: AppType.caption(t).copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Every group as a bar against the target marks, biggest first.
class _BreakdownList extends ConsumerWidget {
  final List<MuscleBalance> balance;
  final TrainingGoals goals;

  const _BreakdownList({required this.balance, required this.goals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final maxPerWeek = balance.isEmpty
        ? 0.0
        : balance.map((b) => b.setsPerWeek).reduce(math.max);
    // Whichever reaches higher sets the scale: the whole band has to stay in
    // the track when every group is far below it, and every bar has to when
    // the user has set a band low enough to be cleared.
    final barMax = math.max(maxPerWeek * 1.08, goals.setsMax * 1.25);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < balance.length; i++)
            FadeSlideIn(
              index: i,
              child: RangeBar(
                label: balance[i].group,
                value: balance[i].setsPerWeek,
                max: barMax,
                valueLabel: _perWeek(balance[i].setsPerWeek),
                valueColor: balance[i].status == VolumeStatus.none
                    ? t.textSecondary
                    : null,
                color: muscleStatusColor(t, balance[i].status),
                valueIcon: balance[i].status == VolumeStatus.optimal
                    ? Icons.check_rounded
                    : null,
                valueIconColor: t.success,
                rangeMin: goals.setsMin,
                rangeMax: goals.setsMax,
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
                const RangeLegendGlyph(),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    // The default band is the one from the literature; a band
                    // the user chose is theirs, and saying otherwise would put
                    // words in the research's mouth.
                    goals.isDefault
                        ? 'Target ${goals.bandSentence}'
                        : 'Your target, ${goals.bandSentence}',
                    style: AppType.secondary(t),
                  ),
                ),
                Text(
                  'Change',
                  style: AppType.secondary(t).copyWith(
                    color: t.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The groups below the band and roughly how many weekly sets would lift each
/// one into it. Plain numbers: a gap is a plan, not a warning.
class _AddList extends ConsumerWidget {
  final List<MuscleBalance> lagging;

  const _AddList({required this.lagging});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lagging.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.divider),
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lagging[i].group,
                            style: AppType.body(t)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            lagging[i].status == VolumeStatus.none
                                ? 'Not trained in this window'
                                : 'At ${_perWeek(lagging[i].setsPerWeek)}',
                            style: AppType.caption(t),
                          ),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '+${math.max(1, lagging[i].setsToTarget)}',
                            style: AppType.mono(
                              t,
                              size: 16,
                              weight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: ' sets/wk',
                            style: AppType.caption(t)
                                .copyWith(color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// [AnalyticsService.muscleGroupSets] files exercises that are missing from the
/// master-exercise library under "Other". Rather than quietly dropping them,
/// say so — otherwise the numbers look wrong to anyone who counts.
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
          Icon(Icons.help_outline_rounded, size: 18, color: t.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$sets ${sets == 1 ? 'set' : 'sets'} '
              '(${share.toStringAsFixed(share < 10 ? 1 : 0)}%) came from '
              'exercises without a muscle group and are left out above.',
              style: AppType.secondary(t),
            ),
          ),
        ],
      ),
    );
  }
}
