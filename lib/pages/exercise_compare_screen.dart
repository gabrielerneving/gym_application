import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/progression_chart_widget.dart';
import '../widgets/ui/ui.dart';
import 'progression_screen.dart';

/// How the two lifts are put on the same axis.
enum _CompareMode {
  /// Percentage change from each exercise's first session in the window. The
  /// only fair way to put a 140 kg squat next to a 45 kg curl.
  relative,

  /// Raw estimated 1RM in kilos.
  absolute,
}

/// ---------------------------------------------------------------------------
/// Compare two exercises side by side: one chart, one table, one verdict.
///
/// Everything is computed from the cached [trainingDataProvider] snapshot and
/// scoped to the shared [statsPeriodProvider] window.
/// ---------------------------------------------------------------------------
class ExerciseCompareScreen extends ConsumerStatefulWidget {
  /// Pre-selects the left-hand exercise (Progression passes the lift you were
  /// already looking at). Falls back to the two most recently trained.
  final String? initialA;
  final String? initialB;

  const ExerciseCompareScreen({super.key, this.initialA, this.initialB});

  @override
  ConsumerState<ExerciseCompareScreen> createState() =>
      _ExerciseCompareScreenState();
}

class _ExerciseCompareScreenState extends ConsumerState<ExerciseCompareScreen> {
  static const String _title = 'Compare';

  String? _a;
  String? _b;
  _CompareMode _mode = _CompareMode.relative;

  @override
  void initState() {
    super.initState();
    _a = widget.initialA;
    _b = widget.initialB;
  }

  Future<void> _refresh() async {
    ref.invalidate(workoutSessionsProvider);
    await ref.read(trainingDataProvider.future);
  }

  Future<void> _pick({
    required List<String> names,
    required Map<String, int> counts,
    required String current,
    required String other,
    required Color accent,
    required bool isA,
  }) async {
    final picked = await ExercisePickerSheet.show(
      context: context,
      ref: ref,
      names: names,
      sessionCounts: counts,
      selected: current,
      title: isA ? 'First exercise' : 'Second exercise',
      accent: accent,
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isA) {
        // Picking the one already in the other slot swaps them instead of
        // comparing a lift with itself.
        if (picked == other) _b = current;
        _a = picked;
      } else {
        if (picked == other) _a = current;
        _b = picked;
      }
    });
  }

  Widget _periodSelector(StatsPeriod period) {
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trainingDataProvider);
    final period = ref.watch(statsPeriodProvider);

    return async.when(
      loading: () => AppScaffold(
        title: _title,
        subtitle: period.longLabel,
        headerBottom: _periodSelector(period),
        children: const [
          SkeletonCard(height: 104),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 42, radius: AppRadius.pill),
          SizedBox(height: AppSpacing.lg),
          SkeletonCard(height: 280),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 200),
        ],
      ),
      error: (error, _) => AppScaffold(
        title: _title,
        subtitle: period.longLabel,
        body: ErrorState(
          message: 'Could not load your training history.\n$error',
          onRetry: () => ref.invalidate(workoutSessionsProvider),
        ),
      ),
      data: (data) => _buildContent(context, data, period),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TrainingData data,
    StatsPeriod period,
  ) {
    final t = ref.watch(themeProvider);

    final isAllTime = period == StatsPeriod.all;
    final scoped = isAllTime
        ? data.sessions
        : AnalyticsService.sessionsIn(data.sessions, period.range());

    // One pass over the window gives every exercise's progress at once.
    final progressByName = isAllTime
        ? data.exerciseProgress
        : AnalyticsService.allExerciseProgress(scoped);

    // Keep the recency ordering from the analytics layer.
    final names = data.exerciseNames
        .where((name) => (progressByName[name]?.points.length ?? 0) > 0)
        .toList();

    if (names.length < 2) {
      return AppScaffold(
        title: _title,
        subtitle: period.longLabel,
        headerBottom: _periodSelector(period),
        onRefresh: _refresh,
        body: EmptyState(
          icon: Icons.compare_arrows_rounded,
          title: isAllTime ? 'Nothing to compare yet' : 'Not enough in view',
          message: isAllTime
              ? 'Log working sets for at least two different exercises and you '
                  'can put them head to head here.'
              : 'Fewer than two exercises have working sets in the '
                  '${period.longLabel.toLowerCase()} window. Widen the period '
                  'to compare.',
          actionLabel: isAllTime ? 'Go back' : 'Show all time',
          onAction: () {
            if (isAllTime) {
              Navigator.of(context).maybePop();
            } else {
              ref.read(statsPeriodProvider.notifier).state = StatsPeriod.all;
            }
          },
        ),
      );
    }

    final nameA = (_a != null && names.contains(_a)) ? _a! : names.first;
    final nameB = (_b != null && names.contains(_b) && _b != nameA)
        ? _b!
        : names.firstWhere((name) => name != nameA);

    final progressA = progressByName[nameA] ??
        ExerciseProgress(name: nameA, points: const []);
    final progressB = progressByName[nameB] ??
        ExerciseProgress(name: nameB, points: const []);

    final counts = <String, int>{
      for (final name in names) name: progressByName[name]?.points.length ?? 0,
    };

    final colorA = t.dataColor(0);
    final colorB = t.dataColor(1);

    return AppScaffold(
      title: _title,
      subtitle: period.longLabel,
      headerBottom: _periodSelector(period),
      onRefresh: _refresh,
      children: [
        // Intrinsic height so both cards match when one name wraps to two lines.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PickCard(
                  slot: 'A',
                  exercise: nameA,
                  sessionCount: progressA.points.length,
                  color: colorA,
                  onTap: () => _pick(
                    names: names,
                    counts: counts,
                    current: nameA,
                    other: nameB,
                    accent: colorA,
                    isA: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _PickCard(
                  slot: 'B',
                  exercise: nameB,
                  sessionCount: progressB.points.length,
                  color: colorB,
                  onTap: () => _pick(
                    names: names,
                    counts: counts,
                    current: nameB,
                    other: nameA,
                    accent: colorB,
                    isA: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSegmented<_CompareMode>(
          value: _mode,
          segments: const [
            AppSegment(
              value: _CompareMode.relative,
              label: 'Relative %',
            ),
            AppSegment(
              value: _CompareMode.absolute,
              label: 'Absolute kg',
            ),
          ],
          onChanged: (value) => setState(() => _mode = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        _CompareChartCard(
          progressA: progressA,
          progressB: progressB,
          colorA: colorA,
          colorB: colorB,
          mode: _mode,
        ),
        const SizedBox(height: AppSpacing.md),
        _VerdictCard(
          text: _verdict(progressA, progressB, period),
        ),
        const SizedBox(height: AppSpacing.md),
        _ComparisonTable(
          progressA: progressA,
          progressB: progressB,
          colorA: colorA,
          colorB: colorB,
        ),
        const SizedBox(height: AppSpacing.md),
        _FootNote(
          text: 'Estimated 1RM uses the Epley formula on your heaviest set of '
              '12 reps or fewer. Trend is a least-squares fit across the '
              'sessions in view.',
        ),
      ],
    );
  }

  /// Weekly 1RM growth expressed as a fraction of the lift's own size, so a
  /// 2.5 kg week on a curl is not drowned out by a 2.5 kg week on a deadlift.
  static double _relativeRate(ExerciseProgress progress) {
    final best = progress.bestOneRm;
    if (best <= 0) return 0.0;
    return progress.oneRmPerWeek / best;
  }

  String _verdict(
    ExerciseProgress a,
    ExerciseProgress b,
    StatsPeriod period,
  ) {
    final window = period == StatsPeriod.all
        ? 'across your whole history'
        : 'over the ${period.longLabel.toLowerCase()}';

    if (a.points.length < 2 || b.points.length < 2) {
      return 'Log at least two sessions of both lifts $window and the trend '
          'comparison lands here.';
    }

    final rateA = _relativeRate(a);
    final rateB = _relativeRate(b);

    if (rateA <= 0 && rateB <= 0) {
      return 'Neither ${a.name} nor ${b.name} has gained ground $window.';
    }
    if (rateB <= 0) {
      return '${a.name} is the only one moving $window — ${b.name} is flat or '
          'drifting down.';
    }
    if (rateA <= 0) {
      return '${b.name} is the only one moving $window — ${a.name} is flat or '
          'drifting down.';
    }

    final ratio = rateA >= rateB ? rateA / rateB : rateB / rateA;
    if (ratio < 1.15) {
      return '${a.name} and ${b.name} are progressing at about the same rate '
          '$window.';
    }

    final faster = rateA >= rateB ? a.name : b.name;
    final slower = rateA >= rateB ? b.name : a.name;
    final shown = ratio >= 10 ? '10×+' : '${ratio.toStringAsFixed(1)}×';

    return '$faster is progressing $shown faster than $slower $window.';
  }
}

/// ---------------------------------------------------------------------------
/// Pieces of the page
/// ---------------------------------------------------------------------------

class _PickCard extends ConsumerWidget {
  final String slot;
  final String exercise;
  final int sessionCount;
  final Color color;
  final VoidCallback onTap;

  const _PickCard({
    required this.slot,
    required this.exercise,
    required this.sessionCount,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  slot,
                  style: AppType.overline(t).copyWith(color: color),
                ),
              ),
              Icon(Icons.unfold_more_rounded, size: 17, color: t.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            exercise,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.heading(t).copyWith(fontSize: 15.5),
          ),
          const SizedBox(height: 3),
          Text(
            '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'}',
            style: AppType.caption(t),
          ),
        ],
      ),
    );
  }
}

class _CompareChartCard extends ConsumerWidget {
  final ExerciseProgress progressA;
  final ExerciseProgress progressB;
  final Color colorA;
  final Color colorB;
  final _CompareMode mode;

  const _CompareChartCard({
    required this.progressA,
    required this.progressB,
    required this.colorA,
    required this.colorB,
    required this.mode,
  });

  /// Absolute kilos, or percentage change from each lift's own starting point.
  static List<double> _values(ExerciseProgress progress, _CompareMode mode) {
    final raw = progress.oneRmSeries;
    if (mode == _CompareMode.absolute) return raw;

    var base = 0.0;
    for (final value in raw) {
      if (value > 0) {
        base = value;
        break;
      }
    }
    if (base <= 0) return List<double>.filled(raw.length, 0.0);
    return [for (final value in raw) ((value - base) / base) * 100];
  }

  static ProgressionSeries _series(
    ExerciseProgress progress,
    Color color,
    _CompareMode mode,
  ) {
    return ProgressionSeries(
      label: progress.name,
      dates: [for (final point in progress.points) point.date],
      values: _values(progress, mode),
      color: color,
      unit: mode == _CompareMode.absolute ? 'kg' : '%',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final isRelative = mode == _CompareMode.relative;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Estimated 1RM', style: AppType.heading(t)),
                const SizedBox(height: 3),
                Text(
                  isRelative
                      ? 'Percentage change from each lift\'s first session in '
                          'view'
                      : 'Raw kilos — useful only when the two lifts are '
                          'similar in size',
                  style: AppType.caption(t),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ProgressionChartWidget(
            key: ValueKey<String>(
              '${progressA.name}|${progressB.name}|${mode.name}',
            ),
            series: [
              _series(progressA, colorA, mode),
              _series(progressB, colorB, mode),
            ],
            height: 232,
            axisLabel: isRelative ? (value) => '${value.round()}%' : null,
            emptyMessage: 'No sessions in this window',
          ),
        ],
      ),
    );
  }
}

class _VerdictCard extends ConsumerWidget {
  final String text;

  const _VerdictCard({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      gradient: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 17, color: t.onPrimary),
              const SizedBox(width: 6),
              Text(
                'VERDICT',
                style: AppType.overline(t).copyWith(color: t.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            style: AppType.title(t).copyWith(
              color: t.onPrimary,
              fontSize: 19,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Based on weekly 1RM growth, scaled to each lift\'s own size.',
            style: AppType.secondary(t)
                .copyWith(color: t.onPrimary.withValues(alpha: 0.82)),
          ),
        ],
      ),
    );
  }
}

/// One row of the head-to-head table.
class _TableRow {
  final String label;
  final String valueA;
  final String valueB;

  /// 0 → A wins, 1 → B wins, -1 → tie.
  final int winner;

  const _TableRow({
    required this.label,
    required this.valueA,
    required this.valueB,
    required this.winner,
  });

  factory _TableRow.numeric(
    String label,
    double a,
    double b,
    String Function(double) format,
  ) {
    return _TableRow(
      label: label,
      valueA: format(a),
      valueB: format(b),
      winner: a > b ? 0 : (b > a ? 1 : -1),
    );
  }

  factory _TableRow.date(String label, DateTime? a, DateTime? b) {
    var winner = -1;
    if (a != null && b != null) {
      if (a.isAfter(b)) {
        winner = 0;
      } else if (b.isAfter(a)) {
        winner = 1;
      }
    } else if (a != null) {
      winner = 0;
    } else if (b != null) {
      winner = 1;
    }

    return _TableRow(
      label: label,
      valueA: a == null ? '—' : AppFormat.relativeDate(a),
      valueB: b == null ? '—' : AppFormat.relativeDate(b),
      winner: winner,
    );
  }
}

class _ComparisonTable extends ConsumerWidget {
  final ExerciseProgress progressA;
  final ExerciseProgress progressB;
  final Color colorA;
  final Color colorB;

  const _ComparisonTable({
    required this.progressA,
    required this.progressB,
    required this.colorA,
    required this.colorB,
  });

  static String _percent(double value) {
    final sign = value > 0 ? '+' : (value < 0 ? '−' : '');
    return '$sign${value.abs().toStringAsFixed(1)}%';
  }

  List<_TableRow> _rows() {
    return [
      _TableRow.numeric(
        'Sessions logged',
        progressA.points.length.toDouble(),
        progressB.points.length.toDouble(),
        (value) => value.round().toString(),
      ),
      _TableRow.numeric(
        'Best weight',
        progressA.bestWeight,
        progressB.bestWeight,
        (value) => '${AppFormat.weight(value)} kg',
      ),
      _TableRow.numeric(
        'Estimated 1RM',
        progressA.bestOneRm,
        progressB.bestOneRm,
        (value) => '${AppFormat.weight(value)} kg',
      ),
      _TableRow.numeric(
        'Total gain',
        progressA.totalGainPercent,
        progressB.totalGainPercent,
        _percent,
      ),
      _TableRow.numeric(
        'Trend / week',
        progressA.oneRmPerWeek,
        progressB.oneRmPerWeek,
        (value) => AppFormat.delta(value, unit: 'kg'),
      ),
      _TableRow.date(
        'Last performed',
        progressA.latest?.date,
        progressB.latest?.date,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final rows = _rows();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 5,
                child: Text('HEAD TO HEAD', style: AppType.overline(t)),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  progressA.name,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t).copyWith(
                    color: colorA,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 4,
                child: Text(
                  progressB.name,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t).copyWith(
                    color: colorB,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, thickness: 1, color: t.divider),
          for (var i = 0; i < rows.length; i++)
            FadeSlideIn(
              index: i,
              offsetY: 10,
              child: _ComparisonRow(
                row: rows[i],
                colorA: colorA,
                colorB: colorB,
              ),
            ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends ConsumerWidget {
  final _TableRow row;
  final Color colorA;
  final Color colorB;

  const _ComparisonRow({
    required this.row,
    required this.colorA,
    required this.colorB,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    TextStyle styleFor(bool wins, Color color) => AppType.mono(
          t,
          size: 13.5,
          weight: wins ? FontWeight.w800 : FontWeight.w600,
        ).copyWith(color: wins ? color : t.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - 2),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.secondary(t),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              row.valueA,
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: styleFor(row.winner == 0, colorA),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 4,
            child: Text(
              row.valueB,
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: styleFor(row.winner == 1, colorB),
            ),
          ),
        ],
      ),
    );
  }
}

class _FootNote extends ConsumerWidget {
  final String text;

  const _FootNote({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: t.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppType.caption(t)),
          ),
        ],
      ),
    );
  }
}
