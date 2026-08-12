import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/progression_chart_widget.dart';
import '../widgets/ui/ui.dart';
import 'exercise_compare_screen.dart';

/// The three ways of looking at one lift over time.
enum _ProgressionMetric {
  oneRm(
    'Est. 1RM',
    'Estimated 1RM',
    'Epley estimate from your heaviest set of 12 reps or fewer',
    'kg',
  ),
  weight(
    'Top weight',
    'Top weight',
    'The heaviest working set in each session',
    'kg',
  ),
  volume(
    'Volume',
    'Session volume',
    'Weight × reps across every working set',
    'kg',
  );

  const _ProgressionMetric(this.label, this.title, this.description, this.unit);

  /// Segment label — kept short so three fit on one row.
  final String label;

  /// Heading above the chart.
  final String title;

  final String description;
  final String unit;

  double valueOf(ExercisePoint point) => switch (this) {
        _ProgressionMetric.oneRm => point.estimatedOneRm,
        _ProgressionMetric.weight => point.topWeight,
        _ProgressionMetric.volume => point.volume,
      };

  double bestOf(ExerciseProgress progress) => switch (this) {
        _ProgressionMetric.oneRm => progress.bestOneRm,
        _ProgressionMetric.weight => progress.bestWeight,
        _ProgressionMetric.volume => progress.bestVolume,
      };

  List<double> seriesOf(ExerciseProgress progress) => switch (this) {
        _ProgressionMetric.oneRm => progress.oneRmSeries,
        _ProgressionMetric.weight => progress.weightSeries,
        _ProgressionMetric.volume => progress.volumeSeries,
      };

  /// Change from the first session in view to the latest, as a percentage.
  double gainOf(ExerciseProgress progress) {
    if (this == _ProgressionMetric.oneRm) return progress.totalGainPercent;
    if (progress.points.length < 2) return 0.0;
    final first = valueOf(progress.points.first);
    if (first <= 0) return 0.0;
    return ((valueOf(progress.points.last) - first) / first) * 100;
  }

  /// Tonnage gets compacted ("12.5k"); weights keep one decimal.
  String format(double value) => this == _ProgressionMetric.volume
      ? AppFormat.compact(value)
      : AppFormat.weight(value);

  /// Session-to-session change reads better as a percentage for volume, which
  /// swings by hundreds of kilos, and as absolute kilos for the two strength
  /// metrics.
  bool get deltaAsPercent => this == _ProgressionMetric.volume;
}

/// ---------------------------------------------------------------------------
/// Progression — one exercise, three metrics, every session behind it.
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

  /// Maximum number of session rows rendered — the list is not lazy.
  static const int _maxRows = 40;

  String? _exercise;

  /// Program-title filter. Null means "every workout".
  String? _program;

  _ProgressionMetric _metric = _ProgressionMetric.oneRm;

  Future<void> _refresh() async {
    ref.invalidate(workoutSessionsProvider);
    await ref.read(trainingDataProvider.future);
  }

  /// Exercises that actually have working sets behind them, newest first.
  List<String> _plottableNames(TrainingData data) {
    final names = data.exerciseNames
        .where((name) => (data.exerciseProgress[name]?.points.length ?? 0) > 0)
        .toList();
    return names;
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
          SkeletonCard(height: 84),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 42, radius: AppRadius.pill),
          SizedBox(height: AppSpacing.lg),
          SkeletonCard(height: 148),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 300),
        ],
      ),
      error: (error, _) => AppScaffold(
        title: _title,
        body: ErrorState(
          message: 'Could not load your training history.\n$error',
          onRetry: () => ref.invalidate(workoutSessionsProvider),
        ),
      ),
      data: (data) => _buildContent(context, data),
    );
  }

  Widget _buildContent(BuildContext context, TrainingData data) {
    final names = _plottableNames(data);

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

    final counts = <String, int>{
      for (final name in names)
        name: data.exerciseProgress[name]?.points.length ?? 0,
    };

    return AppScaffold(
      title: _title,
      subtitle: exercise,
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
          value: _metric,
          segments: const [
            AppSegment(
              value: _ProgressionMetric.oneRm,
              label: 'Est. 1RM',
            ),
            AppSegment(
              value: _ProgressionMetric.weight,
              label: 'Top weight',
            ),
            AppSegment(
              value: _ProgressionMetric.volume,
              label: 'Volume',
            ),
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
          _SummaryCard(progress: progress, metric: _metric),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(progress: progress, metric: _metric),
          if (progress.isStalled) ...[
            const SizedBox(height: AppSpacing.md),
            _PlateauCard(progress: progress),
          ],
          const SizedBox(height: AppSpacing.md),
          _CompareCta(onTap: () => _openCompare(context, exercise)),
          SectionHeader(
            title: 'Sessions',
            subtitle: _sessionsSubtitle(progress.points.length, program),
          ),
          ..._sessionRows(progress),
        ],
      ],
    );
  }

  String _sessionsSubtitle(int count, String? program) {
    final noun = count == 1 ? 'session' : 'sessions';
    return program == null
        ? '$count $noun logged'
        : '$count $noun in $program';
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

  List<Widget> _sessionRows(ExerciseProgress progress) {
    final points = progress.points;
    final total = points.length;
    final limit = total > _maxRows ? _maxRows : total;

    final rows = <Widget>[];
    for (var i = 0; i < limit; i++) {
      // Newest first.
      final index = total - 1 - i;
      rows.add(
        FadeSlideIn(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SessionRow(
              point: points[index],
              previous: index > 0 ? points[index - 1] : null,
              metric: _metric,
            ),
          ),
        ),
      );
    }

    if (total > limit) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            'Showing the $limit most recent of $total sessions.',
            textAlign: TextAlign.center,
            style: AppType.caption(ref.watch(themeProvider)),
          ),
        ),
      );
    }

    return rows;
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
      subtitle: '${names.length} '
          '${names.length == 1 ? 'exercise' : 'exercises'} in your history',
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
                                .copyWith(color: t.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            count == 1 ? 'session' : 'sessions',
                            style: AppType.caption(t),
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
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
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

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const IconBadge(icon: Icons.fitness_center_rounded, filled: true),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('EXERCISE', style: AppType.overline(t)),
                const SizedBox(height: 4),
                Text(
                  exercise,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.heading(t).copyWith(fontSize: 18),
                ),
                const SizedBox(height: 3),
                Text(
                  date == null
                      ? '$sessionCount sessions'
                      : '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'} · '
                          '${AppFormat.relativeDate(date)}',
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

class _ProgramFilterRow extends ConsumerWidget {
  final List<String> programs;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ProgramFilterRow({
    required this.programs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          AppChip(
            label: 'All workouts',
            icon: Icons.all_inclusive_rounded,
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

class _SummaryCard extends ConsumerWidget {
  final ExerciseProgress progress;
  final _ProgressionMetric metric;

  const _SummaryCard({required this.progress, required this.metric});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final current = metric.valueOf(progress.points.last);
    final best = metric.bestOf(progress);
    final gain = metric.gainOf(progress);
    final trend = progress.oneRmPerWeek;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('LATEST SESSION', style: AppType.overline(t)),
                    const SizedBox(height: AppSpacing.sm),
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
                        const SizedBox(width: 5),
                        Text(metric.unit, style: AppType.caption(t)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DeltaBadge(delta: gain, percent: true),
                  const SizedBox(height: 5),
                  Text('since first session', style: AppType.caption(t)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, thickness: 1, color: t.divider),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.emoji_events_rounded,
                  label: 'All-time best',
                  value: '${metric.format(best)} ${metric.unit}',
                ),
              ),
              Container(width: 1, height: 34, color: t.divider),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: _MiniStat(
                    icon: trend < 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                    label: '1RM trend',
                    value: AppFormat.delta(trend, unit: 'kg/week'),
                    color: t.deltaColor(trend),
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

class _MiniStat extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = color ?? t.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color ?? t.textTertiary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption(t),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.mono(t, size: 16).copyWith(color: tone),
        ),
      ],
    );
  }
}

class _ChartCard extends ConsumerWidget {
  final ExerciseProgress progress;
  final _ProgressionMetric metric;

  const _ChartCard({required this.progress, required this.metric});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final series = ProgressionSeries(
      label: progress.name,
      dates: [for (final point in progress.points) point.date],
      values: metric.seriesOf(progress),
      color: t.primary,
      unit: metric.unit,
    );

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
                Text(metric.title, style: AppType.heading(t)),
                const SizedBox(height: 3),
                Text(metric.description, style: AppType.caption(t)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ProgressionChartWidget(
            key: ValueKey<String>('${progress.name}|${metric.name}'),
            series: [series],
            height: 226,
            emptyMessage: 'No sessions to plot yet',
          ),
        ],
      ),
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
      color: t.warning.withValues(alpha: t.isDark ? 0.10 : 0.07),
      border: Border.all(color: t.warning.withValues(alpha: 0.28)),
      shadow: const [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: Icons.trending_flat_rounded,
            color: t.warning,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Progress has stalled', style: AppType.heading(t)),
                const SizedBox(height: 4),
                Text(
                  '${ExerciseProgress.stallWindow} sessions without beating '
                  '${AppFormat.weight(best)} kg estimated. Next time drop to '
                  '${AppFormat.weight(target)} kg for 4×5, then add 2.5 kg a '
                  'week — or swap in a close variation for a month and come '
                  'back to it.',
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

class _CompareCta extends ConsumerWidget {
  final VoidCallback onTap;

  const _CompareCta({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      gradient: true,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.compare_arrows_rounded,
              size: 22,
              color: t.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Compare two lifts',
                  style: AppType.heading(t).copyWith(color: t.onPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'See which one is actually moving faster',
                  style: AppType.secondary(t)
                      .copyWith(color: t.onPrimary.withValues(alpha: 0.82)),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.onPrimary, size: 22),
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
          Icon(Icons.filter_alt_rounded, size: 28, color: t.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nothing to plot',
            textAlign: TextAlign.center,
            style: AppType.heading(t),
          ),
          const SizedBox(height: AppSpacing.xs),
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
            icon: Icons.all_inclusive_rounded,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  final ExercisePoint point;
  final ExercisePoint? previous;
  final _ProgressionMetric metric;

  const _SessionRow({
    required this.point,
    required this.previous,
    required this.metric,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    double? delta;
    final before = previous;
    if (before != null) {
      final past = metric.valueOf(before);
      final now = metric.valueOf(point);
      if (metric.deltaAsPercent) {
        delta = past > 0 ? ((now - past) / past) * 100 : 0.0;
      } else {
        delta = now - past;
      }
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
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
                  style: AppType.heading(t).copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormat.relativeDate(point.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${AppFormat.weight(point.topWeight)} kg × '
                  '${point.topWeightReps}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono(t, size: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppFormat.compact(point.volume)} kg · ${point.sets} '
                  '${point.sets == 1 ? 'set' : 'sets'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t),
                ),
              ],
            ),
          ),
          if (delta != null) ...[
            const SizedBox(width: AppSpacing.sm),
            DeltaBadge(
              delta: delta,
              unit: 'kg',
              percent: metric.deltaAsPercent,
              compact: true,
              fontSize: 11.5,
            ),
          ],
        ],
      ),
    );
  }
}
