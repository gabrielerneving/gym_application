import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/workout_session_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../utils/workout_comparison.dart';
import '../widgets/ui/ui.dart';
import '../widgets/workout_comparison_list.dart';

/// A single completed session.
///
/// Read-only by default: three totals, then one set table per exercise. A set
/// counts once it has reps (weight 0 is a bodyweight set); the empty sets and
/// skipped exercises that older builds saved are hidden, not deleted.
///
/// The pencil in the header switches to edit mode, where a typo'd set can be
/// fixed, removed or added, the duration corrected, or the whole workout
/// deleted. Every change overwrites the stored session and refreshes the
/// statistics, and — because next session's suggestions come from history —
/// the numbers suggested next time too.
///
/// RIR and progression follow `workoutSettingsProvider`.
class WorkoutDetailPage extends ConsumerStatefulWidget {
  final WorkoutSession session;

  const WorkoutDetailPage({super.key, required this.session});

  @override
  ConsumerState<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends ConsumerState<WorkoutDetailPage> {
  static final DateFormat _dateFormat = DateFormat('EEEE, MMMM d, yyyy');

  /// The session as shown — starts as [WorkoutDetailPage.session] and follows
  /// local edits immediately, before Firestore has confirmed them.
  late WorkoutSession _session;

  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void didUpdateWidget(covariant WorkoutDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      _session = widget.session;
      _editing = false;
    }
  }

  // --- Persistence -----------------------------------------------------------

  /// Shows [updated] right away and writes it in the background.
  ///
  /// Firestore applies the write to its local cache at once, so the statistics
  /// are refreshed before the server answers — and a slow gym connection never
  /// leaves the page hanging. A rejected write rolls the page back.
  Future<void> _commit(WorkoutSession updated, String message) async {
    final db = ref.read(databaseServiceProvider);
    if (db == null) return;

    final previous = _session;
    setState(() => _session = updated);

    final write = db.saveWorkoutSession(updated);
    ref.invalidate(workoutSessionsProvider);
    AppSnack.show(context, ref, message);

    try {
      await write;
    } catch (_) {
      if (!mounted) return;
      if (identical(_session, updated)) setState(() => _session = previous);
      ref.invalidate(workoutSessionsProvider);
      AppSnack.show(
        context,
        ref,
        'Could not save the change. Please try again.',
        isError: true,
      );
    }
  }

  /// [sets] replaces the sets of the exercise at [exerciseIndex]. An exercise
  /// left with no sets at all is dropped, as finishing a workout does.
  WorkoutSession _withSets(int exerciseIndex, List<CompletedSet> sets) {
    final exercises = [..._session.completedExercises];
    if (sets.isEmpty) {
      exercises.removeAt(exerciseIndex);
    } else {
      exercises[exerciseIndex] = exercises[exerciseIndex].copyWith(sets: sets);
    }
    return _session.copyWith(completedExercises: exercises);
  }

  // --- Actions ---------------------------------------------------------------

  // Each action notes the session it opened its sheet on: if that changed in
  // the meantime (a failed write rolled it back), the positions it holds may
  // no longer point at the same set, so the edit is dropped.

  Future<void> _editSet(_ExerciseView exercise, _SetLine line) async {
    final source = _session;
    final result = await AppSheet.show<_SetEdit>(
      context: context,
      ref: ref,
      title: 'Edit set',
      subtitle: exercise.name,
      builder: (_) => _SetEditorSheet(
        initial: line.set,
        showRir: ref.read(workoutSettingsProvider).showRIR,
      ),
    );
    if (result == null || !mounted || !identical(_session, source)) return;

    final sets = [..._session.completedExercises[exercise.index].sets];
    final edited = result.set;
    if (edited == null) {
      sets.removeAt(line.index);
      await _commit(_withSets(exercise.index, sets), 'Set removed');
    } else {
      sets[line.index] = _rebaseProgression(line.set, edited);
      await _commit(_withSets(exercise.index, sets), 'Set updated');
    }
  }

  Future<void> _addSet(_ExerciseView exercise) async {
    final source = _session;
    final result = await AppSheet.show<_SetEdit>(
      context: context,
      ref: ref,
      title: 'Add set',
      subtitle: exercise.name,
      builder: (_) => _SetEditorSheet(
        showRir: ref.read(workoutSettingsProvider).showRIR,
      ),
    );
    final added = result?.set;
    if (added == null || !mounted || !identical(_session, source)) return;

    final sets = [..._session.completedExercises[exercise.index].sets];
    if (added.isWarmUp) {
      // Warm-ups go after the existing warm-ups, ahead of the working sets.
      sets.insert(sets.lastIndexWhere((s) => s.isWarmUp) + 1, added);
    } else {
      sets.add(added);
    }
    await _commit(_withSets(exercise.index, sets), 'Set added');
  }

  Future<void> _editDuration() async {
    final source = _session;
    final minutes = await AppSheet.show<int>(
      context: context,
      ref: ref,
      title: 'Duration',
      subtitle: 'How long the session took, in minutes.',
      builder: (_) => _DurationSheet(minutes: _session.durationInMinutes),
    );
    if (minutes == null || !mounted || !identical(_session, source)) return;
    if (minutes == _session.durationInMinutes) return;
    await _commit(
      _session.copyWith(durationInMinutes: minutes),
      'Duration updated',
    );
  }

  Future<void> _delete() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Delete workout?',
      message: 'It is removed from your history and statistics. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final db = ref.read(databaseServiceProvider);
    if (db == null) return;

    // Same reasoning as [_commit]: the local cache drops the session at once,
    // so leave immediately instead of waiting for the server. If the delete
    // is rejected, the history stream simply brings the session back.
    unawaited(
      db.deleteWorkoutSession(_session.id).catchError((Object _) {}),
    );
    ref.invalidate(workoutSessionsProvider);
    AppSnack.show(
      context,
      ref,
      'Workout deleted',
      icon: Icons.delete_outline_rounded,
    );
    Navigator.of(context).maybePop();
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(workoutSettingsProvider);
    final canEdit =
        _session.id.isNotEmpty && ref.watch(databaseServiceProvider) != null;
    final view = _SessionView.of(_session);

    // Against everything logged before this session — the same rules as the
    // summary shown when it was finished, so both read the same.
    final history =
        ref.watch(workoutSessionsProvider).valueOrNull ?? const <WorkoutSession>[];
    final comparison = compareWithHistory(
      session: _session,
      history: [
        for (final s in history)
          if (s.id != _session.id && s.date.isBefore(_session.date)) s,
      ],
    );

    final title = _session.programTitle.trim().isEmpty
        ? 'Workout'
        : _session.programTitle;
    final date = _dateFormat.format(_session.date);

    // One layout for every card: a column is shown when any exercise in the
    // session needs it, so the tables line up as you scroll.
    final layout = _TableLayout(
      rir: settings.showRIR && view.exercises.any((e) => e.hasRir),
      deltas: settings.showProgression &&
          view.exercises.any(
            (e) => e.sets.any((line) => _SetRow.hasDelta(line.set)),
          ),
      editing: _editing,
    );

    if (view.exercises.isEmpty) {
      return AppScaffold(
        title: title,
        subtitle: date,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'Nothing logged',
                message: 'No sets were logged in this session.',
              ),
              if (canEdit)
                AppButton.danger(
                  label: 'Delete workout',
                  icon: Icons.delete_outline_rounded,
                  onPressed: _delete,
                ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      title: title,
      subtitle: _editing ? 'Tap a set to change it' : date,
      actions: [
        if (canEdit)
          AppIconButton(
            icon: _editing ? Icons.check_rounded : Icons.edit_rounded,
            tooltip: _editing ? 'Done' : 'Edit workout',
            active: _editing,
            onPressed: () => setState(() => _editing = !_editing),
          ),
      ],
      children: [
        const SizedBox(height: AppSpacing.sm),
        FadeSlideIn(
          child: _SummaryCard(
            view: view,
            setDelta: comparison.setDelta,
            onEditDuration: _editing ? _editDuration : null,
          ),
        ),
        if (comparison.exercises.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(
            child: AppCard(
              // The rows carry their own air, so the bottom edge needs less
              // padding than the top to look even.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: WorkoutComparisonList(comparison: comparison),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < view.exercises.length; i++)
          FadeSlideIn(
            index: i + 1,
            child: _ExerciseCard(
              exercise: view.exercises[i],
              layout: layout,
              showProgression: settings.showProgression,
              onEditSet: (line) => _editSet(view.exercises[i], line),
              onAddSet: () => _addSet(view.exercises[i]),
            ),
          ),
        if (_editing) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton.danger(
            label: 'Delete workout',
            icon: Icons.delete_outline_rounded,
            expand: true,
            onPressed: _delete,
          ),
        ],
      ],
    );
  }
}

/// Re-derives the progression fields of a set after [edited] replaced
/// [original].
///
/// Sessions store only the deltas against last time, not last time's numbers,
/// so the previous set is reconstructed from the stored delta where one
/// exists. When it can't be, the now-stale delta is dropped rather than
/// guessed — a fixed typo must not keep showing "+700 kg".
CompletedSet _rebaseProgression(CompletedSet original, CompletedSet edited) {
  CompletedSet withDeltas(int? reps, double? weight) => CompletedSet(
        weight: edited.weight,
        reps: edited.reps,
        notes: edited.notes,
        isWarmUp: edited.isWarmUp,
        rir: edited.rir,
        progression: reps,
        weightProgression: weight,
      );

  if (edited.isWarmUp) return withDeltas(null, null);
  if (!original.isWarmUp &&
      edited.weight == original.weight &&
      edited.reps == original.reps) {
    return withDeltas(original.progression, original.weightProgression);
  }

  double round(double v) => (v * 100).round() / 100;

  double? previousWeight;
  int? previousReps;
  if (!original.isWarmUp) {
    if (original.weightProgression != null) {
      previousWeight = round(original.weight - original.weightProgression!);
    } else if (original.progression != null) {
      // Rep deltas are only recorded at an unchanged weight.
      previousWeight = original.weight;
      previousReps = original.reps - original.progression!;
    }
  }
  if (previousWeight == null) return withDeltas(null, null);

  final weightDelta = round(edited.weight - previousWeight);
  final repDelta = previousReps == null ? 0 : edited.reps - previousReps;

  return withDeltas(
    // Rep change at an unchanged weight — including 0, a bodyweight set.
    weightDelta == 0 && repDelta != 0 ? repDelta : null,
    edited.weight > 0 && weightDelta != 0 ? weightDelta : null,
  );
}

/// ---------------------------------------------------------------------------
/// Summary
/// ---------------------------------------------------------------------------

class _SummaryCard extends ConsumerWidget {
  final _SessionView view;

  /// Makes the duration tappable — set in edit mode only.
  final VoidCallback? onEditDuration;

  /// Working sets against the previous session of this program, if any.
  final int? setDelta;

  const _SummaryCard({
    required this.view,
    required this.onEditDuration,
    this.setDelta,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final minutes = view.durationMinutes;

    // Three equal columns, each centred on its own third with a hairline
    // between them, so the strip reads as one balanced row rather than
    // three numbers drifting left.
    Widget divider() => Container(width: 1, height: 36, color: t.divider);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              value: minutes > 0 ? AppFormat.duration(minutes) : '—',
              label: 'Duration',
              onTap: onEditDuration,
            ),
          ),
          divider(),
          Expanded(
            child: _SummaryStat(
              value: '${view.workingSets}',
              label: view.workingSets == 1 ? 'Set' : 'Sets',
              delta: setDelta,
            ),
          ),
          divider(),
          Expanded(
            // A bodyweight-only session has no tonnage — reps say more.
            child: view.volume > 0
                ? _SummaryStat(
                    value: AppFormat.compact(view.volume),
                    unit: 'kg',
                    label: 'Volume',
                  )
                : _SummaryStat(value: '${view.reps}', label: 'Reps'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends ConsumerWidget {
  final String value;
  final String? unit;
  final String label;
  final VoidCallback? onTap;

  /// Signed change against last time, shown beside the label.
  final int? delta;

  const _SummaryStat({
    required this.value,
    required this.label,
    this.unit,
    this.onTap,
    this.delta,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.metric(t, size: 24),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: AppSpacing.xxs),
                Text(unit!, style: AppType.secondary(t)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(t).copyWith(color: t.textSecondary),
                ),
              ),
              if (delta != null && delta != 0) ...[
                const SizedBox(width: AppSpacing.xs),
                DeltaBadge(delta: delta!, compact: true, fontSize: 11),
              ],
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.edit_rounded, size: 12, color: t.primary),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Pressable(
      onTap: onTap,
      haptic: HapticStrength.selection,
      child: content,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Exercises
/// ---------------------------------------------------------------------------

/// The set table's layout, decided once for the whole session so every card
/// lines its columns up with the next one.
///
/// SET is a narrow label on the left; KG, REPS (and RIR) share the middle in
/// equal centred columns; the change against last time is right-aligned in a
/// fixed column at the end; in edit mode a pencil slot closes the row.
class _TableLayout {
  final bool rir;
  final bool deltas;
  final bool editing;

  const _TableLayout({
    required this.rir,
    required this.deltas,
    required this.editing,
  });

  static const double set = 32;
  static const double delta = 76;
  static const double edit = 28;
}

class _ExerciseCard extends ConsumerWidget {
  final _ExerciseView exercise;
  final _TableLayout layout;
  final bool showProgression;
  final ValueChanged<_SetLine> onEditSet;
  final VoidCallback onAddSet;

  const _ExerciseCard({
    required this.exercise,
    required this.layout,
    required this.showProgression,
    required this.onEditSet,
    required this.onAddSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.heading(t),
          ),
          const SizedBox(height: AppSpacing.md),
          _SetHeader(layout: layout),
          for (final line in exercise.sets)
            _SetRow(
              line: line,
              layout: layout,
              showProgression: showProgression,
              onTap: layout.editing ? () => onEditSet(line) : null,
            ),
          if (layout.editing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Center(
                child: AppButton.ghost(
                  label: 'Add set',
                  icon: Icons.add_rounded,
                  size: AppButtonSize.small,
                  onPressed: onAddSet,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The cells of one table row, in column order. Shared by the header and the
/// rows so the two can never disagree about where a column is.
List<Widget> _cells(
  _TableLayout layout, {
  required Widget set,
  required Widget kg,
  required Widget reps,
  required Widget rir,
  required Widget delta,
  required Widget edit,
}) {
  return [
    SizedBox(width: _TableLayout.set, child: set),
    Expanded(child: Center(child: kg)),
    Expanded(child: Center(child: reps)),
    if (layout.rir) Expanded(child: Center(child: rir)),
    if (layout.deltas)
      SizedBox(
        width: _TableLayout.delta,
        child: Align(alignment: Alignment.centerRight, child: delta),
      ),
    if (layout.editing)
      SizedBox(
        width: _TableLayout.edit,
        child: Align(alignment: Alignment.centerRight, child: edit),
      ),
  ];
}

class _SetHeader extends ConsumerWidget {
  final _TableLayout layout;

  const _SetHeader({required this.layout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final style = AppType.overline(t).copyWith(
      fontSize: 10.5,
      color: t.textSecondary,
      letterSpacing: 0.9,
    );

    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      child: Row(
        children: _cells(
          layout,
          set: Text('SET', style: style),
          kg: Text('KG', style: style),
          reps: Text('REPS', style: style),
          rir: Text('RIR', style: style),
          delta: Text('VS LAST', style: style),
          edit: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// One line of the set table. Warm-ups carry an amber "W" and muted numbers;
/// the change against last time sits right-aligned in its own column.
class _SetRow extends ConsumerWidget {
  final _SetLine line;
  final _TableLayout layout;
  final bool showProgression;

  /// Set in edit mode only.
  final VoidCallback? onTap;

  const _SetRow({
    required this.line,
    required this.layout,
    required this.showProgression,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final set = line.set;

    final numbers = AppType.mono(t, size: 15).copyWith(
      color: set.isWarmUp ? t.textSecondary : t.text,
    );
    final label = AppType.mono(t, size: 13).copyWith(
      color: set.isWarmUp ? t.warning : t.textSecondary,
      fontWeight: set.isWarmUp ? FontWeight.w800 : FontWeight.w600,
    );
    final quiet = AppType.mono(t, size: 13).copyWith(color: t.textSecondary);
    final note = set.notes?.trim() ?? '';

    final Widget delta;
    if (set.isWarmUp || !showProgression) {
      delta = const SizedBox.shrink();
    } else {
      // A working set with nothing to compare against still gets a mark, so
      // the column never looks like it lost a value.
      delta = _delta(set) ??
          Text('–', style: quiet.copyWith(color: t.textTertiary));
    }

    final hasRir = (set.rir ?? 0) > 0;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: _cells(
              layout,
              set: Text(set.isWarmUp ? 'W' : line.label, style: label),
              kg: Text(
                set.weight > 0 ? AppFormat.weight(set.weight) : 'BW',
                style: set.weight > 0
                    ? numbers
                    : numbers.copyWith(color: t.textSecondary),
              ),
              reps: Text('${set.reps}', style: numbers),
              rir: Text(
                hasRir ? '${set.rir}' : '–',
                style: hasRir ? quiet : quiet.copyWith(color: t.textTertiary),
              ),
              delta: delta,
              edit: Icon(
                Icons.edit_rounded,
                size: 15,
                color: t.textSecondary,
              ),
            ),
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: _TableLayout.set,
                top: AppSpacing.xxs,
              ),
              child: Text(
                note,
                style: AppType.caption(t).copyWith(
                  color: t.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      haptic: HapticStrength.selection,
      child: row,
    );
  }

  /// Rep and weight deltas are never recorded together — a rep change is only
  /// tracked at an unchanged weight — so at most one of them shows.
  static Widget? _delta(CompletedSet set) {
    final weight = set.weightProgression ?? 0;
    if (weight != 0) {
      return DeltaBadge(
        delta: weight,
        unit: 'kg',
        compact: true,
        fontSize: 11.5,
      );
    }
    final reps = set.progression ?? 0;
    if (reps != 0) {
      return DeltaBadge(
        delta: reps,
        unit: reps.abs() == 1 ? 'rep' : 'reps',
        compact: true,
        fontSize: 11.5,
      );
    }
    return null;
  }

  /// Whether this set shows a change against last time at all.
  static bool hasDelta(CompletedSet set) =>
      !set.isWarmUp &&
      ((set.weightProgression ?? 0) != 0 || (set.progression ?? 0) != 0);
}

/// ---------------------------------------------------------------------------
/// Editing sheets
/// ---------------------------------------------------------------------------

/// What the set editor returns: a replacement set, or a removal.
class _SetEdit {
  /// Null means "remove this set".
  final CompletedSet? set;

  const _SetEdit.save(CompletedSet this.set);
  const _SetEdit.remove() : set = null;
}

/// Weight, reps, optional RIR and note for one set. With no [initial] it adds
/// a set instead of editing one.
class _SetEditorSheet extends ConsumerStatefulWidget {
  final CompletedSet? initial;
  final bool showRir;

  const _SetEditorSheet({this.initial, required this.showRir});

  @override
  ConsumerState<_SetEditorSheet> createState() => _SetEditorSheetState();
}

class _SetEditorSheetState extends ConsumerState<_SetEditorSheet> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final TextEditingController _rir;
  late final TextEditingController _note;
  late bool _warmUp;

  String? _weightError;
  String? _repsError;

  bool get _adding => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _weight = TextEditingController(
      text: initial != null && initial.weight > 0
          ? _editable(initial.weight)
          : '',
    );
    _reps = TextEditingController(
      text: initial != null && initial.reps > 0 ? '${initial.reps}' : '',
    );
    _rir = TextEditingController(
      text: (initial?.rir ?? 0) > 0 ? '${initial!.rir}' : '',
    );
    _note = TextEditingController(text: initial?.notes?.trim() ?? '');
    _warmUp = initial?.isWarmUp ?? false;
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _rir.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Full precision for the text field — [AppFormat.weight] rounds 82.25 to
  /// "82.3", which would silently change the set when saved.
  static String _editable(double weight) => weight == weight.roundToDouble()
      ? weight.toStringAsFixed(0)
      : weight.toString();

  void _save() {
    final weightText = _weight.text.trim().replaceAll(',', '.');
    final weight = weightText.isEmpty ? 0.0 : double.tryParse(weightText);
    final reps = int.tryParse(_reps.text.trim()) ?? 0;

    setState(() {
      _weightError = weight == null ? 'Not a number' : null;
      _repsError = reps > 0 ? null : 'At least 1';
    });
    if (weight == null || reps <= 0) return;

    final note = _note.text.trim();
    final initial = widget.initial;

    Navigator.of(context).pop(
      _SetEdit.save(
        CompletedSet(
          weight: weight,
          reps: reps,
          notes: note.isEmpty ? null : note,
          isWarmUp: _warmUp,
          // Hidden RIR is kept as it was; empty means "not noted", stored as 0
          // exactly like the active workout does.
          rir: widget.showRir
              ? (int.tryParse(_rir.text.trim()) ?? 0)
              : initial?.rir,
          progression: initial?.progression,
          weightProgression: initial?.weightProgression,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final numbers = AppType.mono(t, size: 17);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _weight,
                    autofocus: _adding,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    textInputAction: TextInputAction.next,
                    cursorColor: t.primary,
                    style: numbers,
                    decoration: InputDecoration(
                      labelText: 'Weight',
                      hintText: 'BW',
                      suffixText: 'kg',
                      errorText: _weightError,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _reps,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: widget.showRir
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: widget.showRir ? null : (_) => _save(),
                    cursorColor: t.primary,
                    style: numbers,
                    decoration: InputDecoration(
                      labelText: 'Reps',
                      errorText: _repsError,
                    ),
                  ),
                ),
                if (widget.showRir) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rir,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      cursorColor: t.primary,
                      style: numbers,
                      decoration: const InputDecoration(labelText: 'RIR'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              cursorColor: t.primary,
              style: AppType.body(t),
              decoration: const InputDecoration(hintText: 'Note (optional)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: AppChip(
                label: 'Warm-up set',
                selected: _warmUp,
                onTap: () => setState(() => _warmUp = !_warmUp),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (_adding)
              AppButton(
                label: 'Add set',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: _save,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: AppButton.danger(
                      label: 'Remove',
                      icon: Icons.delete_outline_rounded,
                      onPressed: () =>
                          Navigator.of(context).pop(const _SetEdit.remove()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(label: 'Save', onPressed: _save),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Fixes the duration of a session — mostly for the one whose timer kept
/// running long after the last set.
class _DurationSheet extends ConsumerStatefulWidget {
  final int minutes;

  const _DurationSheet({required this.minutes});

  @override
  ConsumerState<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends ConsumerState<_DurationSheet> {
  /// A day. Anything longer is a typo.
  static const int _maxMinutes = 24 * 60;

  late final TextEditingController _controller = TextEditingController(
    text: widget.minutes > 0 ? '${widget.minutes}' : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_controller.text.trim()) ?? 0;
    if (minutes <= 0 || minutes > _maxMinutes) {
      setState(() => _error = 'Between 1 and $_maxMinutes minutes');
      return;
    }
    Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              cursorColor: t.primary,
              style: AppType.mono(t, size: 17),
              decoration: InputDecoration(
                labelText: 'Minutes',
                suffixText: 'min',
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(label: 'Save', expand: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Derived data
/// ---------------------------------------------------------------------------

/// A logged set and where it lives in the stored session.
class _SetLine {
  /// Position in [CompletedExercise.sets], counting the hidden empty sets.
  final int index;
  final CompletedSet set;

  /// Working-set number ("1", "2" …); warm-ups are labelled by the row.
  final String label;

  const _SetLine({required this.index, required this.set, required this.label});
}

class _ExerciseView {
  /// Position in [WorkoutSession.completedExercises].
  final int index;
  final String name;
  final List<_SetLine> sets;

  const _ExerciseView({
    required this.index,
    required this.name,
    required this.sets,
  });

  bool get hasRir => sets.any((line) => (line.set.rir ?? 0) > 0);
}

/// What the page shows of a session: only sets with reps, only exercises with
/// such sets, and the totals over the working ones.
class _SessionView {
  final List<_ExerciseView> exercises;
  final int durationMinutes;
  final int workingSets;
  final int reps;
  final double volume;

  const _SessionView({
    required this.exercises,
    required this.durationMinutes,
    required this.workingSets,
    required this.reps,
    required this.volume,
  });

  factory _SessionView.of(WorkoutSession session) {
    final exercises = <_ExerciseView>[];
    var workingSets = 0;
    var reps = 0;
    var volume = 0.0;

    for (var e = 0; e < session.completedExercises.length; e++) {
      final exercise = session.completedExercises[e];
      final lines = <_SetLine>[];
      var number = 0;

      for (var s = 0; s < exercise.sets.length; s++) {
        final set = exercise.sets[s];
        if (set.reps <= 0) continue;
        if (!set.isWarmUp) {
          number++;
          workingSets++;
          reps += set.reps;
          volume += set.weight * set.reps;
        }
        lines.add(_SetLine(index: s, set: set, label: '$number'));
      }

      if (lines.isEmpty) continue;
      exercises.add(_ExerciseView(
        index: e,
        name: exercise.name.trim().isEmpty ? 'Exercise' : exercise.name.trim(),
        sets: lines,
      ));
    }

    return _SessionView(
      exercises: exercises,
      durationMinutes: session.durationInMinutes,
      workingSets: workingSets,
      reps: reps,
      volume: volume,
    );
  }
}
