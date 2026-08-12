import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../utils/one_rm_calculator.dart';
import '../widgets/ui/ui.dart';

/// ---------------------------------------------------------------------------
/// 1RM — estimated strength across the whole exercise library.
///
/// The screen is a leaderboard: every lift the user has ever logged, ranked by
/// its best estimated one-rep max. Tapping a lift opens a detail page whose
/// centrepiece is the percentage-of-1RM table you actually want while standing
/// at the rack.
///
/// Everything is derived from [trainingDataProvider] — one cached fetch of the
/// session history — instead of the old per-exercise database round trips.
/// ---------------------------------------------------------------------------

/// The estimation formula in use. Held in a provider so the leaderboard and the
/// detail page always show the same numbers.
final _formulaProvider =
    StateProvider<OneRMFormula>((ref) => OneRMFormula.epley);

/// The rungs of the percentage table. Anything below 60% stops being a working
/// weight and starts being a warm-up.
const List<double> _trainingPercentages = [
  95.0,
  90.0,
  85.0,
  80.0,
  75.0,
  70.0,
  65.0,
  60.0,
];

/// Estimates are only trustworthy from sets in this rep range.
const int _maxEstimateReps = 12;

class OneRMScreen extends ConsumerWidget {
  const OneRMScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formula = ref.watch(_formulaProvider);
    final async = ref.watch(trainingDataProvider);

    return async.when(
      loading: () => AppScaffold(
        title: '1RM',
        subtitle: formula.displayName,
        actions: [_FormulaAction(formula: formula)],
        children: const [_LoadingSkeleton()],
      ),
      error: (error, _) => AppScaffold(
        title: '1RM',
        subtitle: formula.displayName,
        actions: [_FormulaAction(formula: formula)],
        body: ErrorState(
          message: 'Could not load your training history.',
          onRetry: () {
            ref.invalidate(workoutSessionsProvider);
            ref.invalidate(exerciseMuscleMapProvider);
          },
        ),
      ),
      data: (data) {
        final entries = _buildEntries(data, formula);

        if (entries.isEmpty) {
          return AppScaffold(
            title: '1RM',
            subtitle: formula.displayName,
            actions: [_FormulaAction(formula: formula)],
            onRefresh: () => _refresh(ref),
            body: EmptyState(
              icon: Icons.fitness_center_rounded,
              title: data.isEmpty ? 'No workouts yet' : 'Nothing to estimate',
              message: data.isEmpty
                  ? 'Finish a workout and your estimated maxes show up here.'
                  : 'A 1RM needs a working set of $_maxEstimateReps reps or '
                      'fewer. Log one and it appears here.',
              actionLabel: 'Log a workout',
              onAction: () => Navigator.of(context).maybePop(),
            ),
          );
        }

        final top = entries.first;
        final rest = entries.skip(1).toList();

        return AppScaffold(
          title: '1RM',
          subtitle: '${entries.length} lifts · ${formula.displayName}',
          actions: [_FormulaAction(formula: formula)],
          onRefresh: () => _refresh(ref),
          children: [
            const SizedBox(height: AppSpacing.sm),
            const Overline('Estimation formula'),
            FadeSlideIn(child: _FormulaTile(formula: formula)),
            const SizedBox(height: AppSpacing.xl),
            FadeSlideIn(index: 1, child: _HeroLift(entry: top)),
            if (rest.isNotEmpty) ...[
              const SectionHeader(
                title: 'All lifts',
                subtitle: 'Heaviest estimate first',
              ),
              for (var i = 0; i < rest.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: FadeSlideIn(
                    index: i + 2,
                    child: _LeaderboardRow(entry: rest[i], rank: i + 2),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _MethodNote(formula: formula),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Data assembly
// ---------------------------------------------------------------------------

/// The single set that produced an exercise's best estimate.
class _BestSet {
  final double oneRm;
  final double weight;
  final int reps;
  final DateTime date;

  const _BestSet({
    required this.oneRm,
    required this.weight,
    required this.reps,
    required this.date,
  });
}

/// One row of the leaderboard.
class _OneRmEntry {
  final String exercise;
  final _BestSet best;
  final ExerciseProgress progress;

  const _OneRmEntry({
    required this.exercise,
    required this.best,
    required this.progress,
  });

  /// The estimate curve, with sessions that produced no usable estimate
  /// (everything above [_maxEstimateReps] reps) dropped so the line does not
  /// dive to zero.
  List<double> get series => [
        for (final p in progress.points)
          if (p.estimatedOneRm > 0) p.estimatedOneRm,
      ];
}

/// Walks the history once and records the best estimated 1RM per exercise,
/// together with the exact set it came from. Pass [only] to score a single
/// exercise.
Map<String, _BestSet> _bestSets(
  TrainingData data,
  OneRMFormula formula, {
  String? only,
}) {
  final out = <String, _BestSet>{};

  for (final session in data.sessions) {
    for (final exercise in session.completedExercises) {
      if (only != null && exercise.name != only) continue;
      for (final s in exercise.sets) {
        if (!AnalyticsService.isWorkingSet(s)) continue;
        if (s.reps > _maxEstimateReps) continue;

        final estimate = OneRMCalculator.calculate(s.weight, s.reps, formula);
        if (estimate <= 0) continue;

        final current = out[exercise.name];
        if (current == null || estimate > current.oneRm) {
          out[exercise.name] = _BestSet(
            oneRm: estimate,
            weight: s.weight,
            reps: s.reps,
            date: session.date,
          );
        }
      }
    }
  }

  return out;
}

List<_OneRmEntry> _buildEntries(TrainingData data, OneRMFormula formula) {
  // Epley is already memoised on the snapshot; anything else is one extra pass.
  final progress = formula == OneRMFormula.epley
      ? data.exerciseProgress
      : AnalyticsService.allExerciseProgress(data.sessions, formula: formula);

  final entries = <_OneRmEntry>[];
  _bestSets(data, formula).forEach((name, best) {
    entries.add(_OneRmEntry(
      exercise: name,
      best: best,
      progress: progress[name] ??
          ExerciseProgress(name: name, points: const []),
    ));
  });

  entries.sort((a, b) => b.best.oneRm.compareTo(a.best.oneRm));
  return entries;
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

void _openDetail(BuildContext context, String exercise) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _OneRmDetailPage(exercise: exercise),
    ),
  );
}

// ---------------------------------------------------------------------------
// Formula picking
// ---------------------------------------------------------------------------

Future<void> _showFormulaSheet(
  BuildContext context,
  WidgetRef ref,
  OneRMFormula current,
) {
  return AppSheet.show<void>(
    context: context,
    ref: ref,
    title: 'Estimation formula',
    subtitle: 'Every number on this screen is recalculated.',
    builder: (sheetContext) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < OneRMFormula.values.length; i++)
              FadeSlideIn(
                index: i,
                offsetY: 10,
                child: _FormulaOption(
                  formula: OneRMFormula.values[i],
                  selected: OneRMFormula.values[i] == current,
                  onTap: () {
                    ref.read(_formulaProvider.notifier).state =
                        OneRMFormula.values[i];
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _FormulaAction extends ConsumerWidget {
  final OneRMFormula formula;

  const _FormulaAction({required this.formula});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppIconButton(
      icon: Icons.calculate_rounded,
      tooltip: 'Formula',
      onPressed: () => _showFormulaSheet(context, ref, formula),
    );
  }
}

class _FormulaTile extends ConsumerWidget {
  final OneRMFormula formula;

  const _FormulaTile({required this.formula});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppTile(
      icon: Icons.calculate_rounded,
      title: formula.displayName,
      subtitle: formula.description,
      onTap: () => _showFormulaSheet(context, ref, formula),
    );
  }
}

class _FormulaOption extends ConsumerWidget {
  final OneRMFormula formula;
  final bool selected;
  final VoidCallback onTap;

  const _FormulaOption({
    required this.formula,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Pressable(
      onTap: onTap,
      haptic: HapticStrength.selection,
      scale: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? t.primaryWash : t.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? t.primaryWashOutline : t.outline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formula.displayName,
                    style: AppType.heading(t).copyWith(
                      color: selected ? t.primary : t.text,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(formula.description, style: AppType.secondary(t)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? t.primary : t.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leaderboard
// ---------------------------------------------------------------------------

class _HeroLift extends ConsumerWidget {
  final _OneRmEntry entry;

  const _HeroLift({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final series = entry.series;

    return AppCard(
      gradient: true,
      onTap: () => _openDetail(context, entry.exercise),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, size: 17, color: t.onPrimary),
              const SizedBox(width: 6),
              Text(
                'Strongest lift',
                style: AppType.overline(t)
                    .copyWith(color: t.onPrimary.withValues(alpha: 0.9)),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: t.onPrimary.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            entry.exercise,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.title(t).copyWith(color: t.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              CountUp(
                value: entry.best.oneRm,
                decimals: 1,
                style: AppType.metric(t, size: 44).copyWith(color: t.onPrimary),
              ),
              const SizedBox(width: 5),
              Text(
                'kg',
                style: AppType.body(t)
                    .copyWith(color: t.onPrimary.withValues(alpha: 0.82)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${AppFormat.weight(entry.best.weight)} kg × ${entry.best.reps} · '
            '${AppFormat.relativeDate(entry.best.date)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.secondary(t)
                .copyWith(color: t.onPrimary.withValues(alpha: 0.82)),
          ),
          if (series.length > 1) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 42,
              child: Sparkline(
                values: series,
                color: t.onPrimary,
                fill: false,
                strokeWidth: 2.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardRow extends ConsumerWidget {
  final _OneRmEntry entry;
  final int rank;

  const _LeaderboardRow({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final series = entry.series;

    return AppCard(
      onTap: () => _openDetail(context, entry.exercise),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: AppType.mono(t, size: 13).copyWith(
                    color: t.textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  entry.exercise,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.heading(t),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppFormat.weight(entry.best.oneRm),
                style: AppType.metric(t, size: 21).copyWith(color: t.primary),
              ),
              const SizedBox(width: 3),
              Text('kg', style: AppType.caption(t)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  '${AppFormat.weight(entry.best.weight)} kg × '
                  '${entry.best.reps} · '
                  '${AppFormat.relativeDate(entry.best.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t),
                ),
              ),
              if (series.length > 1) ...[
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 66,
                  height: 22,
                  child: Sparkline(values: series, color: t.primary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodNote extends ConsumerWidget {
  final OneRMFormula formula;

  const _MethodNote({required this.formula});

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
              'Estimates use ${formula.displayName} over working sets of '
              '$_maxEstimateReps reps or fewer. Warm-up sets are ignored.',
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
        SkeletonCard(height: 76),
        SizedBox(height: AppSpacing.xl),
        SkeletonCard(height: 190),
        SizedBox(height: AppSpacing.xl),
        SkeletonCard(height: 84),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(height: 84),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(height: 84),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail page
// ---------------------------------------------------------------------------

/// Which number the percentage table is built from.
enum _Basis { best, latest }

extension _BasisX on _Basis {
  String get label => this == _Basis.best ? 'Best estimate' : 'Latest session';
  String get shortLabel => this == _Basis.best ? 'best' : 'latest';
}

class _OneRmDetailPage extends ConsumerStatefulWidget {
  final String exercise;

  const _OneRmDetailPage({required this.exercise});

  @override
  ConsumerState<_OneRmDetailPage> createState() => _OneRmDetailPageState();
}

class _OneRmDetailPageState extends ConsumerState<_OneRmDetailPage> {
  _Basis _basis = _Basis.best;

  @override
  Widget build(BuildContext context) {
    final formula = ref.watch(_formulaProvider);
    final async = ref.watch(trainingDataProvider);

    return async.when(
      loading: () => AppScaffold(
        title: widget.exercise,
        subtitle: formula.displayName,
        body: const LoadingState(message: 'Reading your history'),
      ),
      error: (error, _) => AppScaffold(
        title: widget.exercise,
        subtitle: formula.displayName,
        body: ErrorState(
          message: 'Could not load this lift.',
          onRetry: () {
            ref.invalidate(workoutSessionsProvider);
            ref.invalidate(exerciseMuscleMapProvider);
          },
        ),
      ),
      data: (data) {
        // The brief's API: a formula-aware progression for one exercise.
        final progress = formula == OneRMFormula.epley
            ? data.progressFor(widget.exercise)
            : AnalyticsService.exerciseProgress(
                data.sessions,
                widget.exercise,
                formula: formula,
              );

        final points = [
          for (final p in progress.points)
            if (p.estimatedOneRm > 0) p,
        ];
        final best = _bestSets(data, formula, only: widget.exercise)[
            widget.exercise];

        if (points.isEmpty || best == null) {
          return AppScaffold(
            title: widget.exercise,
            subtitle: formula.displayName,
            body: EmptyState(
              icon: Icons.insights_rounded,
              title: 'No estimate yet',
              message: 'Log a working set of $_maxEstimateReps reps or fewer '
                  'for this lift and the numbers appear here.',
              actionLabel: 'Back',
              onAction: () => Navigator.of(context).maybePop(),
            ),
          );
        }

        final latest = points.last;
        final oneRm =
            _basis == _Basis.best ? best.oneRm : latest.estimatedOneRm;

        return AppScaffold(
          title: widget.exercise,
          subtitle: '${formula.displayName} · ${points.length} sessions',
          actions: [_FormulaAction(formula: formula)],
          onRefresh: () => _refresh(ref),
          headerBottom: AppSegmented<_Basis>(
            value: _basis,
            segments: const [
              AppSegment(value: _Basis.best, label: 'Best estimate'),
              AppSegment(value: _Basis.latest, label: 'Latest session'),
            ],
            onChanged: (basis) => setState(() => _basis = basis),
          ),
          children: [
            const SizedBox(height: AppSpacing.sm),
            FadeSlideIn(
              child: _DetailHero(
                oneRm: oneRm,
                basis: _basis,
                best: best,
                points: points,
              ),
            ),
            const SectionHeader(
              title: 'Training percentages',
              subtitle: 'Working weights and the reps they should allow',
            ),
            FadeSlideIn(
              index: 1,
              child: _PercentageTable(oneRm: oneRm, basis: _basis),
            ),
            const SectionHeader(title: 'Estimated 1RM over time'),
            FadeSlideIn(index: 2, child: _CurveCard(points: points)),
            const SectionHeader(title: 'The numbers'),
            FadeSlideIn(
              index: 3,
              child: _DetailStats(
                progress: progress,
                points: points,
                best: best,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _MethodNote(formula: formula),
          ],
        );
      },
    );
  }
}

class _DetailHero extends ConsumerWidget {
  final double oneRm;
  final _Basis basis;
  final _BestSet best;
  final List<ExercisePoint> points;

  const _DetailHero({
    required this.oneRm,
    required this.basis,
    required this.best,
    required this.points,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final latest = points.last;

    final source = basis == _Basis.best
        ? '${AppFormat.weight(best.weight)} kg × ${best.reps} · '
            '${AppFormat.relativeDate(best.date)}'
        : '${AppFormat.weight(latest.topWeight)} kg × '
            '${latest.topWeightReps} · '
            '${AppFormat.relativeDate(latest.date)}';

    final sessionDelta = points.length > 1
        ? latest.estimatedOneRm - points[points.length - 2].estimatedOneRm
        : null;

    return AppCard(
      gradient: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            basis.label,
            style:
                AppType.overline(t).copyWith(color: t.onPrimary.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              CountUp(
                value: oneRm,
                decimals: 1,
                style: AppType.metric(t, size: 46).copyWith(color: t.onPrimary),
              ),
              const SizedBox(width: 5),
              Text(
                'kg',
                style: AppType.body(t)
                    .copyWith(color: t.onPrimary.withValues(alpha: 0.82)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'From $source',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.secondary(t)
                .copyWith(color: t.onPrimary.withValues(alpha: 0.82)),
          ),
          if (sessionDelta != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: t.onPrimary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sessionDelta >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 15,
                    color: t.onPrimary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${AppFormat.delta(sessionDelta, unit: 'kg')} '
                    'vs last session',
                    style: AppType.caption(t).copyWith(
                      color: t.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Zone metadata for a percentage rung.
class _Zone {
  final String label;
  final Color color;

  const _Zone(this.label, this.color);
}

_Zone _zoneFor(AppColors t, double percent) {
  if (percent >= 90) return _Zone('Max strength', t.dataColor(0));
  if (percent >= 80) return _Zone('Strength', t.dataColor(3));
  if (percent >= 70) return _Zone('Hypertrophy', t.dataColor(2));
  return _Zone('Muscular endurance', t.dataColor(1));
}

/// The centrepiece: what to load on the bar for each percentage of the max,
/// and roughly how many reps that should be good for.
class _PercentageTable extends ConsumerWidget {
  final double oneRm;
  final _Basis basis;

  const _PercentageTable({required this.oneRm, required this.basis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Based on your ${basis.shortLabel} estimate of '
            '${AppFormat.weight(oneRm)} kg',
            style: AppType.secondary(t),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const SizedBox(width: 15),
              SizedBox(
                width: 46,
                child: Text('%', style: AppType.overline(t)),
              ),
              Expanded(
                child: Text('Working weight', style: AppType.overline(t)),
              ),
              SizedBox(
                width: 66,
                child: Text(
                  'Reps',
                  textAlign: TextAlign.right,
                  style: AppType.overline(t),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, thickness: 1, color: t.divider),
          for (var i = 0; i < _trainingPercentages.length; i++) ...[
            _PercentRow(percent: _trainingPercentages[i], oneRm: oneRm),
            if (i != _trainingPercentages.length - 1)
              Divider(height: 1, thickness: 1, color: t.divider),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: t.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rep estimates come from the inverted Epley formula. Treat '
                  'them as a ceiling, not a target.',
                  style: AppType.caption(t).copyWith(fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PercentRow extends ConsumerWidget {
  final double percent;
  final double oneRm;

  const _PercentRow({required this.percent, required this.oneRm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final zone = _zoneFor(t, percent);
    final weight = OneRMCalculator.percentageWeight(oneRm, percent);
    final reps = OneRMCalculator.estimatedReps(weight, oneRm);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 1),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: zone.color,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 46,
            child: Text(
              '${percent.toInt()}%',
              style: AppType.mono(t, size: 15).copyWith(color: zone.color),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${AppFormat.weight(weight)} kg',
                  style: AppType.mono(t, size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  zone.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 66,
            child: Text(
              '≈ $reps',
              textAlign: TextAlign.right,
              style: AppType.mono(t, size: 15)
                  .copyWith(color: t.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurveCard extends ConsumerWidget {
  final List<ExercisePoint> points;

  const _CurveCard({required this.points});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    if (points.length < 2) {
      return AppCard(
        child: SizedBox(
          height: 110,
          child: Center(
            child: Text(
              'One session logged so far — the curve appears once there are two.',
              textAlign: TextAlign.center,
              style: AppType.secondary(t),
            ),
          ),
        ),
      );
    }

    final values = [for (final p in points) p.estimatedOneRm];
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = maxValue - minValue;
    final margin = span > 0 ? span * 0.18 : math.max(maxValue * 0.1, 1.0);
    final yMin = math.max(0.0, minValue - margin);
    final yMax = maxValue + margin;
    final yInterval = (yMax - yMin) > 0 ? (yMax - yMin) / 4 : 1.0;
    final xInterval = points.length > 6
        ? (points.length / 4).ceilToDouble()
        : 1.0;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: SizedBox(
        height: 226,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            minY: yMin,
            maxY: yMax,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              drawHorizontalLine: true,
              horizontalInterval: yInterval,
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
                  interval: yInterval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      AppFormat.weight(value.roundToDouble()),
                      style: AppType.caption(t).copyWith(fontSize: 10.5),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: xInterval,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        AppFormat.dayMonth(points[index].date),
                        style: AppType.caption(t).copyWith(fontSize: 10.5),
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
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].estimatedOneRm),
                ],
                isCurved: true,
                gradient: t.primaryGradient,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: points.length <= 20,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 3.5,
                    color: t.primary,
                    strokeWidth: 2,
                    strokeColor: t.card,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: t.chartFillGradient,
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => t.elevated,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.round();
                    if (index < 0 || index >= points.length) return null;
                    final point = points[index];
                    return LineTooltipItem(
                      '${AppFormat.weight(point.estimatedOneRm)} kg\n'
                      '${AppFormat.weight(point.topWeight)} kg × '
                      '${point.topWeightReps} · '
                      '${AppFormat.dayMonth(point.date)}',
                      AppType.caption(t).copyWith(
                        color: t.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    );
                  }).toList();
                },
              ),
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(color: t.primary.withValues(alpha: 0.4), strokeWidth: 2),
                    FlDotData(
                      getDotPainter: (spot, percent, bar, i) =>
                          FlDotCirclePainter(
                        radius: 5.5,
                        color: t.primary,
                        strokeWidth: 2,
                        strokeColor: t.card,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailStats extends ConsumerWidget {
  final ExerciseProgress progress;
  final List<ExercisePoint> points;
  final _BestSet best;

  const _DetailStats({
    required this.progress,
    required this.points,
    required this.best,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final latest = points.last;
    final perWeek = progress.oneRmPerWeek;
    final gain = progress.totalGainPercent;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricRow(
            label: 'Best estimate',
            value: '${AppFormat.weight(best.oneRm)} kg',
            icon: Icons.emoji_events_rounded,
          ),
          MetricRow(
            label: 'From the set',
            value: '${AppFormat.weight(best.weight)} kg × ${best.reps}',
            icon: Icons.fitness_center_rounded,
          ),
          MetricRow(
            label: 'Latest estimate',
            value: '${AppFormat.weight(latest.estimatedOneRm)} kg',
            icon: Icons.show_chart_rounded,
          ),
          MetricRow(
            label: 'Heaviest set ever',
            value: '${AppFormat.weight(progress.bestWeight)} kg',
            icon: Icons.arrow_upward_rounded,
          ),
          MetricRow(
            label: 'Trend',
            value: '${AppFormat.delta(perWeek, unit: 'kg')} / week',
            icon: Icons.trending_up_rounded,
            valueColor: t.deltaColor(perWeek),
          ),
          MetricRow(
            label: 'Total change',
            value: '${gain >= 0 ? '+' : '−'}'
                '${gain.abs().toStringAsFixed(1)}%',
            icon: Icons.timeline_rounded,
            valueColor: t.deltaColor(gain),
          ),
          MetricRow(
            label: 'Sessions logged',
            value: '${progress.points.length}',
            icon: Icons.repeat_rounded,
          ),
          MetricRow(
            label: 'Last trained',
            value: AppFormat.relativeDate(progress.points.last.date),
            icon: Icons.event_rounded,
          ),
          if (progress.isStalled) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                AppBadge(
                  label: 'Plateaued',
                  color: t.warning,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'No new best across the last four sessions.',
                    style: AppType.caption(t),
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
