import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/workout_session_model.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/ui/ui.dart';

/// A single completed session, read-only.
///
/// RIR and progression columns are opt-in and follow
/// `workoutSettingsProvider`; per-set notes stay collapsed until tapped.
class WorkoutDetailPage extends ConsumerStatefulWidget {
  final WorkoutSession session;

  const WorkoutDetailPage({super.key, required this.session});

  @override
  ConsumerState<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends ConsumerState<WorkoutDetailPage> {
  static final DateFormat _dateFormat = DateFormat('EEEE, MMMM d, yyyy');

  /// Keys of the expanded notes, formatted 'exerciseIndex_setIndex'.
  final Set<String> _expandedNotes = <String>{};

  _SessionSummary? _summary;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _summarise();
  }

  @override
  void didUpdateWidget(covariant WorkoutDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      _expandedNotes.clear();
      _summarise();
    }
  }

  /// Aggregates the session up front. Malformed history (a session saved by an
  /// older build, say) surfaces as an error state instead of a red screen.
  void _summarise() {
    try {
      _summary = _SessionSummary.from(widget.session);
      _error = null;
    } catch (e) {
      _summary = null;
      _error = e;
    }
  }

  void _toggleNote(int exerciseIndex, int setIndex) {
    setState(() {
      final key = '${exerciseIndex}_$setIndex';
      if (!_expandedNotes.remove(key)) _expandedNotes.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final title = session.programTitle.trim().isEmpty
        ? 'Workout'
        : session.programTitle;
    final subtitle = _dateFormat.format(session.date);

    if (_error != null) {
      return AppScaffold(
        title: title,
        subtitle: subtitle,
        body: ErrorState(
          message: 'Could not read this session.',
          onRetry: () => setState(_summarise),
        ),
      );
    }

    final summary = _summary;
    if (summary == null) {
      return AppScaffold(
        title: title,
        subtitle: subtitle,
        body: const LoadingState(message: 'Crunching the numbers…'),
      );
    }

    if (summary.exercises.isEmpty) {
      return AppScaffold(
        title: title,
        subtitle: subtitle,
        body: EmptyState(
          icon: Icons.fitness_center_rounded,
          title: 'Nothing logged',
          message: 'This session was saved without any exercises.',
          actionLabel: 'Back to history',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    return AppScaffold(
      title: title,
      subtitle: subtitle,
      children: [
        const SizedBox(height: AppSpacing.sm),
        FadeSlideIn(child: _SummaryCard(summary: summary)),
        SectionHeader(
          title: 'Exercises',
          subtitle: '${summary.exercises.length} '
              '${summary.exercises.length == 1 ? 'exercise' : 'exercises'} · '
              '${summary.workingSets} working sets',
        ),
        for (var i = 0; i < summary.exercises.length; i++)
          FadeSlideIn(
            index: i + 1,
            child: _ExerciseCard(
              summary: summary.exercises[i],
              index: i,
              isNoteExpanded: (setIndex) =>
                  _expandedNotes.contains('${i}_$setIndex'),
              onToggleNote: (setIndex) => _toggleNote(i, setIndex),
            ),
          ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Header
/// ---------------------------------------------------------------------------

class _SummaryCard extends ConsumerWidget {
  final _SessionSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Overline('Session total'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              CountUp(
                value: summary.volume,
                format: AppFormat.compact,
                style: AppType.metric(t, size: 36),
              ),
              const SizedBox(width: 6),
              Text('kg lifted', style: AppType.secondary(t)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: t.divider),
          const SizedBox(height: AppSpacing.xs),
          MetricRow(
            label: 'Duration',
            value: AppFormat.duration(summary.durationMinutes),
            icon: Icons.schedule_rounded,
          ),
          MetricRow(
            label: 'Exercises',
            value: '${summary.exercises.length}',
            icon: Icons.fitness_center_rounded,
          ),
          MetricRow(
            label: 'Working sets',
            value: '${summary.workingSets}',
            icon: Icons.repeat_rounded,
          ),
          MetricRow(
            label: 'Warm-up sets',
            value: '${summary.warmUpSets}',
            icon: Icons.local_fire_department_rounded,
          ),
          MetricRow(
            label: 'Heaviest set',
            value: summary.topSet > 0
                ? '${AppFormat.weight(summary.topSet)} kg'
                : '—',
            icon: Icons.arrow_upward_rounded,
          ),
          MetricRow(
            label: 'Avg reps per set',
            value: summary.workingSets == 0
                ? '—'
                : summary.avgReps.toStringAsFixed(1),
            icon: Icons.bar_chart_rounded,
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Exercises
/// ---------------------------------------------------------------------------

class _ExerciseCard extends ConsumerWidget {
  final _ExerciseSummary summary;
  final int index;
  final bool Function(int setIndex) isNoteExpanded;
  final void Function(int setIndex) onToggleNote;

  const _ExerciseCard({
    required this.summary,
    required this.index,
    required this.isNoteExpanded,
    required this.onToggleNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final settings = ref.watch(workoutSettingsProvider);
    final sets = summary.exercise.sets;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ExerciseLetter(index: index),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  summary.exercise.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.heading(t),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (sets.isEmpty)
            Text('No sets logged.', style: AppType.secondary(t))
          else ...[
            for (var i = 0; i < sets.length; i++)
              _SetRow(
                completedSet: sets[i],
                number: i + 1,
                showRir: settings.showRIR,
                showProgression: settings.showProgression,
                expanded: isNoteExpanded(i),
                onToggleNote: () => onToggleNote(i),
              ),
          ],
          if (summary.workingSets > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _ExerciseSubtotals(summary: summary),
          ],
        ],
      ),
    );
  }
}

/// The A / B / C marker in front of an exercise name.
class _ExerciseLetter extends ConsumerWidget {
  final int index;

  const _ExerciseLetter({required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final label =
        index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.primaryWash,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: t.primaryWashOutline),
      ),
      child: Text(
        label,
        style: AppType.mono(t, size: 15, weight: FontWeight.w800)
            .copyWith(color: t.primary),
      ),
    );
  }
}

/// One line of the set table.
class _SetRow extends ConsumerWidget {
  final CompletedSet completedSet;
  final int number;
  final bool showRir;
  final bool showProgression;
  final bool expanded;
  final VoidCallback onToggleNote;

  const _SetRow({
    required this.completedSet,
    required this.number,
    required this.showRir,
    required this.showProgression,
    required this.expanded,
    required this.onToggleNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final bool hasRir =
        showRir && completedSet.rir != null && completedSet.rir! > 0;
    final int repDelta = showProgression ? (completedSet.progression ?? 0) : 0;
    final double weightDelta =
        showProgression ? (completedSet.weightProgression ?? 0.0) : 0.0;

    final String notes = completedSet.notes?.trim() ?? '';
    final bool hasNotes = notes.isNotEmpty;
    final bool hasDetail = repDelta != 0 || weightDelta != 0 || hasNotes;

    final weightText = completedSet.weight > 0
        ? '${AppFormat.weight(completedSet.weight)} kg'
        : '—';
    final repsText = completedSet.reps > 0 ? '${completedSet.reps}' : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$number',
                  style: AppType.mono(t, size: 13)
                      .copyWith(color: t.textTertiary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$weightText × $repsText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono(t, size: 15),
                ),
              ),
              if (completedSet.isWarmUp) ...[
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: 'Warm-up',
                  icon: Icons.local_fire_department_rounded,
                  color: t.warning,
                  fontSize: 11,
                ),
              ],
              if (hasRir) ...[
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: 'RIR ${completedSet.rir}',
                  color: t.textSecondary,
                  fontSize: 11,
                ),
              ],
            ],
          ),
          if (hasDetail) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (repDelta != 0)
                    DeltaBadge(
                      delta: repDelta,
                      unit: repDelta.abs() == 1 ? 'rep' : 'reps',
                      fontSize: 11.5,
                    ),
                  if (weightDelta != 0)
                    DeltaBadge(
                      delta: weightDelta,
                      unit: 'kg',
                      fontSize: 11.5,
                    ),
                  if (hasNotes)
                    _NoteChip(
                      text: notes,
                      expanded: expanded,
                      onTap: onToggleNote,
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

/// A per-set note, collapsed to one line until tapped.
class _NoteChip extends ConsumerWidget {
  final String text;
  final bool expanded;
  final VoidCallback onTap;

  const _NoteChip({
    required this.text,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Pressable(
      onTap: onTap,
      haptic: HapticStrength.selection,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: t.primaryWash,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: t.primaryWashOutline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notes_rounded, size: 13, color: t.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: expanded ? null : 1,
                overflow:
                    expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                style: AppType.caption(t).copyWith(color: t.text, fontSize: 12),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 14,
              color: t.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sets, tonnage and top set for one exercise.
class _ExerciseSubtotals extends ConsumerWidget {
  final _ExerciseSummary summary;

  const _ExerciseSubtotals({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: t.primaryWash,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MiniStat(label: 'Sets', value: '${summary.workingSets}'),
          ),
          Expanded(
            child: _MiniStat(
              label: 'Volume',
              value: '${AppFormat.compact(summary.volume)} kg',
            ),
          ),
          Expanded(
            child: _MiniStat(
              label: 'Top set',
              value: summary.topSet > 0
                  ? '${AppFormat.weight(summary.topSet)} kg'
                  : '—',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends ConsumerWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.mono(t, size: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption(t).copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Derived data
/// ---------------------------------------------------------------------------

class _ExerciseSummary {
  final CompletedExercise exercise;
  final int workingSets;
  final double volume;
  final double topSet;

  const _ExerciseSummary({
    required this.exercise,
    required this.workingSets,
    required this.volume,
    required this.topSet,
  });
}

class _SessionSummary {
  final int durationMinutes;
  final double volume;
  final int workingSets;
  final int warmUpSets;
  final int reps;
  final double topSet;
  final List<_ExerciseSummary> exercises;

  const _SessionSummary({
    required this.durationMinutes,
    required this.volume,
    required this.workingSets,
    required this.warmUpSets,
    required this.reps,
    required this.topSet,
    required this.exercises,
  });

  double get avgReps => workingSets == 0 ? 0 : reps / workingSets;

  factory _SessionSummary.from(WorkoutSession session) {
    var warmUpSets = 0;
    final exercises = <_ExerciseSummary>[];

    for (final exercise in session.completedExercises) {
      var volume = 0.0;
      var workingSets = 0;
      var topSet = 0.0;

      for (final set in exercise.sets) {
        if (set.isWarmUp) warmUpSets++;
        if (!AnalyticsService.isWorkingSet(set)) continue;
        workingSets++;
        volume += AnalyticsService.setVolume(set);
        if (set.weight > topSet) topSet = set.weight;
      }

      exercises.add(_ExerciseSummary(
        exercise: exercise,
        workingSets: workingSets,
        volume: volume,
        topSet: topSet,
      ));
    }

    return _SessionSummary(
      durationMinutes: session.durationInMinutes,
      volume: AnalyticsService.sessionVolume(session),
      workingSets: AnalyticsService.sessionWorkingSets(session),
      warmUpSets: warmUpSets,
      reps: AnalyticsService.sessionReps(session),
      topSet: AnalyticsService.sessionTopSet(session),
      exercises: exercises,
    );
  }
}
