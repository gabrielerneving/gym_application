import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/progression_chart_widget.dart';
import '../widgets/ui/ui.dart';
import 'exercise_compare_screen.dart';

/// The ways of looking at one lift over time. Loaded lifts get the first
/// three; a lift only ever done at bodyweight has no kilos to chart and gets
/// the two rep metrics instead.
enum _ProgressionMetric {
  oneRm('Est. 1RM', 'kg'),
  weight('Top weight', 'kg'),
  volume('Volume', 'kg'),
  bestReps('Best set', 'reps'),
  totalReps('Total reps', 'reps');

  const _ProgressionMetric(this.label, this.unit);

  /// Segment label — kept short so three fit on one row.
  final String label;
  final String unit;

  static const List<_ProgressionMetric> loaded = [oneRm, weight, volume];
  static const List<_ProgressionMetric> bodyweight = [bestReps, totalReps];

  double valueOf(ExercisePoint point) => switch (this) {
        _ProgressionMetric.oneRm => point.estimatedOneRm,
        _ProgressionMetric.weight => point.topWeight,
        _ProgressionMetric.volume => point.volume,
        _ProgressionMetric.bestReps => point.bestReps.toDouble(),
        _ProgressionMetric.totalReps => point.reps.toDouble(),
      };

  /// The sessions this metric can honestly plot. A bodyweight session has no
  /// top weight and no tonnage, and a session of only high-rep sets has no
  /// 1RM estimate — drawn anyway, each would be a dive to zero.
  List<ExercisePoint> pointsOf(ExerciseProgress progress) => switch (this) {
        _ProgressionMetric.oneRm => progress.ratedPoints,
        _ProgressionMetric.weight ||
        _ProgressionMetric.volume =>
          progress.weightedPoints,
        _ProgressionMetric.bestReps ||
        _ProgressionMetric.totalReps =>
          progress.points,
      };

  /// Tonnage gets compacted ("12.5k"); weights keep one decimal.
  String format(double value) => this == _ProgressionMetric.volume
      ? AppFormat.compact(value)
      : AppFormat.weight(value);

  /// Session-to-session change reads better as a percentage for volume, which
  /// swings by hundreds of kilos, and as absolute numbers for the rest.
  bool get deltaAsPercent => this == _ProgressionMetric.volume;
}

/// ---------------------------------------------------------------------------
/// Progression — one exercise, its metrics, every session behind it.
///
/// Reads the cached [trainingDataProvider] snapshot; nothing here touches
/// Firestore directly.
/// ---------------------------------------------------------------------------
class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  static const String _title = 'Progression';

  /// Session rows shown before "Show all".
  static const int _collapsedRows = 15;

  String? _exercise;

  /// Program-title filter. Null means "every workout".
  String? _program;

  _ProgressionMetric _metric = _ProgressionMetric.oneRm;
  bool _showAllSessions = false;

  Future<void> _refresh() async {
    ref.invalidate(workoutSessionsProvider);
    await ref.read(trainingDataProvider.future);
  }

  Future<void> _pickExercise(
    BuildContext context,
    List<String> names,
    Map<String, int> counts,
    String current,
  ) async {
    final picked = await ExercisePickerSheet.show(
      context: context,
      ref: ref,
      names: names,
      sessionCounts: counts,
      selected: current,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _exercise = picked;
      // The old program filter rarely applies to a different lift.
      _program = null;
      _showAllSessions = false;
    });
  }

  void _openCompare(BuildContext context, String exercise) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExerciseCompareScreen(initialA: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trainingDataProvider);

    return async.when(
      loading: () => const AppScaffold(
        title: _title,
        children: [
          SizedBox(height: AppSpacing.sm),
          // A plain box: the selector card is shorter than a SkeletonCard's
          // three placeholder lines.
          SkeletonBox(height: 74, radius: AppRadius.card),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 42, radius: AppRadius.pill),
          SizedBox(height: AppSpacing.lg),
          SkeletonCard(height: 380),
        ],
      ),
      error: (error, _) => AppScaffold(
        title: _title,
        body: ErrorState(
          message: 'Could not load your training history.',
          onRetry: () => ref.invalidate(workoutSessionsProvider),
        ),
      ),
      data: (data) => _buildContent(context, data),
    );
  }

  Widget _buildContent(BuildContext context, TrainingData data) {
    // Every exercise with at least one working set, newest first.
    final names = data.exerciseNames;

    if (names.isEmpty) {
      return AppScaffold(
        title: _title,
        onRefresh: _refresh,
        body: EmptyState(
          icon: Icons.timeline_rounded,
          title: 'No progression yet',
          message: 'Finish a workout with at least one working set and every '
              'lift you train shows up here.',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final exercise =
        (_exercise != null && names.contains(_exercise)) ? _exercise! : names.first;

    final all = data.progressFor(exercise);
    final programs = _programsOf(all);
    final program =
        (_program != null && programs.contains(_program)) ? _program : null;

    final progress = program == null
        ? all
        : ExerciseProgress(
            name: exercise,
            points: all.points
                .where((point) => point.programTitle == program)
                .toList(),
          );

    final metrics = all.isBodyweight
        ? _ProgressionMetric.bodyweight
        : _ProgressionMetric.loaded;
    final metric = metrics.contains(_metric) ? _metric : metrics.first;

    final counts = <String, int>{
      for (final name in names)
        name: data.exerciseProgress[name]?.points.length ?? 0,
    };

    return AppScaffold(
      title: _title,
      onRefresh: _refresh,
      actions: [
        AppIconButton(
          icon: Icons.compare_arrows_rounded,
          tooltip: 'Compare two exercises',
          onPressed: () => _openCompare(context, exercise),
        ),
      ],
      children: [
        _ExerciseSelectorCard(
          exercise: exercise,
          sessionCount: all.points.length,
          lastPerformed: all.latest?.date,
          onTap: () => _pickExercise(context, names, counts, exercise),
        ),
        if (programs.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          _ProgramFilterRow(
            programs: programs,
            selected: program,
            onChanged: (value) => setState(() => _program = value),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppSegmented<_ProgressionMetric>(
          value: metric,
          segments: [
            for (final m in metrics) AppSegment(value: m, label: m.label),
          ],
          onChanged: (value) => setState(() => _metric = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (progress.points.isEmpty)
          _FilteredEmptyCard(
            exercise: exercise,
            program: program,
            onClear: () => setState(() => _program = null),
          )
        else ...[
          FadeSlideIn(child: _ProgressCard(progress: progress, metric: metric)),
          if (progress.isStalled) ...[
            const SizedBox(height: AppSpacing.md),
            FadeSlideIn(index: 1, child: _PlateauCard(progress: progress)),
          ],
          SectionHeader(
            title: 'Sessions',
            subtitle: program == null
                ? null
                : '${progress.points.length} in $program',
          ),
          FadeSlideIn(
            index: 2,
            child: _SessionList(
              progress: progress,
              metric: metric,
              limit: _showAllSessions ? null : _collapsedRows,
              onShowAll: () => setState(() => _showAllSessions = true),
            ),
          ),
        ],
      ],
    );
  }

  /// Programs this exercise has actually been performed in.
  List<String> _programsOf(ExerciseProgress progress) {
    final titles = <String>{};
    for (final point in progress.points) {
      if (point.programTitle.isNotEmpty) titles.add(point.programTitle);
    }
    final list = titles.toList();
    list.sort();
    return list;
  }
}

/// ---------------------------------------------------------------------------
/// The exercise picker. Lives here because Progression owns it, and is shared
/// with the compare screen so both pickers behave identically.
/// ---------------------------------------------------------------------------
class ExercisePickerSheet extends ConsumerStatefulWidget {
  final List<String> names;
  final Map<String, int> sessionCounts;
  final String? selected;

  /// Tint for the selected row — the compare screen colours A and B.
  final Color? accent;

  const ExercisePickerSheet({
    super.key,
    required this.names,
    required this.sessionCounts,
    this.selected,
    this.accent,
  });

  /// Opens the picker and resolves to the chosen exercise, or null.
  static Future<String?> show({
    required BuildContext context,
    required WidgetRef ref,
    required List<String> names,
    required Map<String, int> sessionCounts,
    String? selected,
    String title = 'Choose exercise',
    Color? accent,
  }) {
    return AppSheet.show<String>(
      context: context,
      ref: ref,
      title: title,
      builder: (context) => ExercisePickerSheet(
        names: names,
        sessionCounts: sessionCounts,
        selected: selected,
        accent: accent,
      ),
    );
  }

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final accent = widget.accent ?? t.primary;
    final query = _query.trim().toLowerCase();

    final matches = query.isEmpty
        ? widget.names
        : widget.names
            .where((name) => name.toLowerCase().contains(query))
            .toList();

    return Padding(
      // The sheet sits above the keyboard rather than behind it.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value),
            onClear: () {
              _controller.clear();
              setState(() => _query = '');
            },
            hasText: _query.isNotEmpty,
          ),
          const SizedBox(height: AppSpacing.md),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Text(
                'Nothing matches "${_query.trim()}".',
                textAlign: TextAlign.center,
                style: AppType.secondary(t),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final name = matches[index];
                  final count = widget.sessionCounts[name] ?? 0;
                  final isSelected = name == widget.selected;

                  return Pressable(
                    scale: 0.99,
                    onTap: () => Navigator.of(context).pop(name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: isSelected ? accent : t.textTertiary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.body(t).copyWith(
                                color: isSelected ? accent : t.text,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '$count',
                            style: AppType.mono(t, size: 13)
                                .copyWith(color: t.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasText;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: t.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: t.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: t.primary,
              textInputAction: TextInputAction.search,
              style: AppType.body(t),
              // The pill is the field: switch off the theme's own outline
              // and fill, which otherwise draw a second box inside it.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search exercises',
                hintStyle: AppType.secondary(t),
              ),
            ),
          ),
          if (hasText)
            Pressable(
              onTap: onClear,
              scale: 0.9,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: t.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Pieces of the page
/// ---------------------------------------------------------------------------

/// One decimal place, so a 0.04 kg wobble reads as no change rather than
/// "+0.0".
double _round1(double value) => (value * 10).round() / 10;

class _ExerciseSelectorCard extends ConsumerWidget {
  final String exercise;
  final int sessionCount;
  final DateTime? lastPerformed;
  final VoidCallback onTap;

  const _ExerciseSelectorCard({
    required this.exercise,
    required this.sessionCount,
    required this.lastPerformed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final date = lastPerformed;
    final sessions = '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'}';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exercise,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.heading(t).copyWith(fontSize: 18),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  date == null
                      ? sessions
                      : '$sessions · ${AppFormat.relativeDate(date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.unfold_more_rounded, size: 20, color: t.textTertiary),
        ],
      ),
    );
  }
}

class _ProgramFilterRow extends StatelessWidget {
  final List<String> programs;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ProgramFilterRow({
    required this.programs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          AppChip(
            label: 'All workouts',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final program in programs) ...[
            const SizedBox(width: AppSpacing.sm),
            AppChip(
              label: program,
              selected: selected == program,
              onTap: () => onChanged(program),
            ),
          ],
        ],
      ),
    );
  }
}

/// The latest number, its change since the first session, the chart, and the
/// best and trend under it — one card for one metric.
class _ProgressCard extends ConsumerWidget {
  final ExerciseProgress progress;
  final _ProgressionMetric metric;

  const _ProgressCard({required this.progress, required this.metric});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final points = metric.pointsOf(progress);

    final chart = ProgressionChartWidget(
      key: ValueKey<String>('${progress.name}|${metric.name}'),
      series: [
        ProgressionSeries(
          label: progress.name,
          dates: [for (final point in points) point.date],
          values: [for (final point in points) metric.valueOf(point)],
          color: t.primary,
          unit: metric.unit,
        ),
      ],
      height: 210,
      emptyMessage: metric == _ProgressionMetric.oneRm
          ? 'No sets of ${AnalyticsService.maxOneRmReps} reps or fewer to '
              'estimate from'
          : 'No loaded sets to plot',
    );

    if (points.isEmpty) return AppCard(child: chart);

    final current = metric.valueOf(points.last);
    final first = metric.valueOf(points.first);
    final best = points.map(metric.valueOf).reduce((a, b) => a > b ? a : b);
    final gain = points.length < 2 || first <= 0
        ? null
        : ((current - first) / first) * 100;
    final trend = AnalyticsService.weeklyTrend(points, metric.valueOf);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: CountUp(
                            value: current,
                            format: metric.format,
                            style: AppType.metric(t, size: 34),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(metric.unit, style: AppType.caption(t)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Latest session', style: AppType.caption(t)),
                  ],
                ),
              ),
              if (gain != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DeltaBadge(delta: gain, percent: true),
                    const SizedBox(height: AppSpacing.xs),
                    Text('since first session', style: AppType.caption(t)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          chart,
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, thickness: 1, color: t.divider),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'All-time best',
                  value: '${metric.format(best)} ${metric.unit}',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Trend',
                  value: points.length < 2
                      ? '—'
                      : '${AppFormat.delta(_round1(trend))} ${metric.unit}/wk',
                  color: points.length < 2 ? null : t.deltaColor(trend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends ConsumerWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppType.caption(t)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.mono(t, size: 16).copyWith(color: color ?? t.text),
        ),
      ],
    );
  }
}

class _PlateauCard extends ConsumerWidget {
  final ExerciseProgress progress;

  const _PlateauCard({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final best = progress.bestOneRm;
    // Back off to ~90% of the estimate, rounded to the nearest plate jump.
    final target = ((best * 0.9) / 2.5).round() * 2.5;

    return AppCard(
      border: Border.all(color: t.warning.withValues(alpha: 0.32)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(Icons.trending_flat_rounded, size: 20, color: t.warning),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stalled for ${ExerciseProgress.stallWindow} sessions',
                  style: AppType.heading(t).copyWith(fontSize: 15),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Try a lighter block around ${AppFormat.weight(target)} kg '
                  'and build back up.',
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

class _FilteredEmptyCard extends ConsumerWidget {
  final String exercise;
  final String? program;
  final VoidCallback onClear;

  const _FilteredEmptyCard({
    required this.exercise,
    required this.program,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      child: Column(
        children: [
          Text(
            program == null
                ? '$exercise has no working sets logged yet.'
                : '$exercise has no logged sets in $program.',
            textAlign: TextAlign.center,
            style: AppType.secondary(t),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.secondary(
            label: 'Show all workouts',
            onPressed: onClear,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }
}

/// Every session, newest first, as rows in one card.
class _SessionList extends ConsumerWidget {
  final ExerciseProgress progress;
  final _ProgressionMetric metric;

  /// Rows to show; null shows everything.
  final int? limit;
  final VoidCallback onShowAll;

  const _SessionList({
    required this.progress,
    required this.metric,
    required this.limit,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final points = progress.points;

    // The change in each row is against the previous session the metric could
    // measure — a bodyweight day in between is skipped, not read as zero.
    final previousValue = <int, double>{};
    double? last;
    for (var i = 0; i < points.length; i++) {
      if (last != null) previousValue[i] = last;
      final value = metric.valueOf(points[i]);
      if (value > 0) last = value;
    }

    final total = points.length;
    final shown = limit == null || total <= limit! ? total : limit!;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shown; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.divider),
            _SessionRow(
              point: points[total - 1 - i],
              previous: previousValue[total - 1 - i],
              metric: metric,
            ),
          ],
          if (shown < total) ...[
            Divider(height: 1, thickness: 1, color: t.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: AppButton.ghost(
                label: 'Show all $total sessions',
                onPressed: onShowAll,
                size: AppButtonSize.small,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  final ExercisePoint point;

  /// The metric's value in the previous measurable session, if any.
  final double? previous;
  final _ProgressionMetric metric;

  const _SessionRow({
    required this.point,
    required this.previous,
    required this.metric,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final now = metric.valueOf(point);
    final before = previous;
    double? delta;
    if (before != null && now > 0) {
      delta = metric.deltaAsPercent
          ? ((now - before) / before) * 100
          : now - before;
    }

    final topSet = point.isBodyweight
        ? '${point.bestReps} reps'
        : '${AppFormat.weight(point.topWeight)} kg × ${point.topWeightReps}';
    final detail = point.isBodyweight
        ? '${point.sets} ${point.sets == 1 ? 'set' : 'sets'} · '
            '${point.reps} reps'
        : '${point.sets} ${point.sets == 1 ? 'set' : 'sets'} · '
            '${AppFormat.compact(point.volume)} kg';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppFormat.dayMonth(point.date),
                  style: AppType.body(t).copyWith(fontWeight: FontWeight.w700),
                ),
                if (point.programTitle.isNotEmpty)
                  Text(
                    point.programTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption(t),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  topSet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono(t, size: 14.5),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            child: Align(
              alignment: Alignment.centerRight,
              child: delta == null
                  ? const SizedBox.shrink()
                  : DeltaBadge(
                      delta: _round1(delta),
                      unit: metric.deltaAsPercent ? '' : metric.unit,
                      percent: metric.deltaAsPercent,
                      compact: true,
                      fontSize: 11.5,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
