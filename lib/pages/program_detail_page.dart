import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';
import '../widgets/workout_widget.dart';
import 'create_workout.dart';

/// A read-only view of a saved program — what it contains and how the sets
/// are planned — with the way to start it.
class ProgramDetailPage extends ConsumerStatefulWidget {
  final WorkoutProgram program;

  const ProgramDetailPage({super.key, required this.program});

  @override
  ConsumerState<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends ConsumerState<ProgramDetailPage> {
  /// The saved copy of this program, live. The page used to render only the
  /// snapshot it was opened with, so coming back from the editor showed the
  /// program as it was before the edit.
  late final Stream<WorkoutProgram?>? _saved = _watchSaved();

  bool _starting = false;

  /// Room under the list for the start button: [AppFab]'s height plus the
  /// air the scaffold leaves under it, and a little more.
  static const double _fabClearance =
      56 + AppSpacing.xxl + AppSpacing.lg;

  Stream<WorkoutProgram?>? _watchSaved() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final id = widget.program.id;
    return DatabaseService(uid: uid).getWorkoutPrograms().map((programs) {
      for (final program in programs) {
        if (program.id == id) return program;
      }
      return null;
    });
  }

  void _openEditor(WorkoutProgram program) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateWorkoutScreen(workoutToEdit: program),
      ),
    );
  }

  void _start(WorkoutProgram program) {
    if (_starting) return;
    launchProgram(
      context,
      ref,
      program,
      // The workout takes this page's place, so finishing it lands on Home.
      replace: true,
      onBusy: (busy) {
        if (mounted) setState(() => _starting = busy);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watched here rather than inside the stream builder below, so the
    // subscription belongs to this widget's own build.
    final id = widget.program.id;
    final isLive = ref.watch(
      workoutProvider.select((s) => s.isRunning && s.session?.id == id),
    );

    return StreamBuilder<WorkoutProgram?>(
      stream: _saved,
      builder: (context, snapshot) {
        // Until the first read lands — or if the program has since been
        // deleted — the copy the page was opened with is the best we have.
        final program = snapshot.data ?? widget.program;
        return _page(program, isLive: isLive);
      },
    );
  }

  Widget _page(WorkoutProgram program, {required bool isLive}) {
    final exercises = program.exercises;

    final actions = <Widget>[
      AppIconButton(
        icon: Icons.edit_rounded,
        tooltip: 'Edit program',
        onPressed: () => _openEditor(program),
      ),
    ];

    if (exercises.isEmpty) {
      return AppScaffold(
        title: program.title,
        actions: actions,
        body: EmptyState(
          icon: Icons.playlist_add_rounded,
          title: 'Nothing planned yet',
          message: 'Add a few exercises and it is ready to run.',
          actionLabel: 'Add exercises',
          onAction: () => _openEditor(program),
        ),
      );
    }

    final workingSets =
        exercises.fold<int>(0, (sum, ex) => sum + ex.workingSets);

    // How this program has been going — history is keyed by title.
    ProgramUsage? usage;
    final programs = ref.watch(trainingDataProvider).valueOrNull?.programs ??
        const <ProgramUsage>[];
    for (final u in programs) {
      if (u.title == program.title) {
        usage = u;
        break;
      }
    }

    return AppScaffold(
      title: program.title,
      subtitle: '${exercises.length} '
          '${exercises.length == 1 ? 'exercise' : 'exercises'} · '
          '$workingSets ${workingSets == 1 ? 'set' : 'sets'}',
      actions: actions,
      // Pushed over the tabs: there is no nav bar to clear, only the button.
      bottomPadding: 0,
      floatingAction: AppFab(
        icon: Icons.play_arrow_rounded,
        label: isLive
            ? 'Resume'
            : _starting
                ? 'Starting…'
                : 'Start workout',
        onPressed: () => _start(program),
      ),
      children: [
        if (usage != null) ...[
          FadeSlideIn(child: _UsageStrip(usage: usage)),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < exercises.length; i++) ...[
                if (i > 0) const _RowDivider(),
                FadeSlideIn(
                  index: i,
                  child: _ExerciseRow(exercise: exercises[i], index: i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: _fabClearance),
      ],
    );
  }
}

/// When the program was last done, how often, and how long it usually takes —
/// three centred columns, the same strip a finished session opens with.
class _UsageStrip extends ConsumerWidget {
  final ProgramUsage usage;

  const _UsageStrip({required this.usage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final now = DateTime.now();
    final last = usage.lastPerformed.isAfter(now) ? now : usage.lastPerformed;
    final minutes = usage.avgMinutes.round();

    Widget divider() => Container(width: 1, height: 36, color: t.divider);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _UsageStat(
              value: AppFormat.dayMonth(last),
              label: 'Last done',
            ),
          ),
          divider(),
          Expanded(
            child: _UsageStat(
              value: '${usage.count}',
              label: usage.count == 1 ? 'Session' : 'Sessions',
            ),
          ),
          divider(),
          Expanded(
            child: _UsageStat(
              value: minutes > 0 ? AppFormat.duration(minutes) : '—',
              label: 'Avg time',
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageStat extends ConsumerWidget {
  final String value;
  final String label;

  const _UsageStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.metric(t, size: 22),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption(t).copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One exercise: its position, its name and the sets planned for it.
class _ExerciseRow extends ConsumerWidget {
  final Exercise exercise;
  final int index;

  const _ExerciseRow({required this.exercise, required this.index});

  /// Width of the position number, so every name starts on the same line.
  /// Two digits' worth — any wider and the number floats away from its name.
  static const double numberWidth = 20;

  /// Air between the number and the name.
  static const double gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final working = exercise.workingSets;
    final warmUp = exercise.warmUpSets;

    final Widget sets;
    if (working <= 0 && warmUp <= 0) {
      sets = Text('No sets', style: AppType.secondary(t));
    } else {
      sets = Text.rich(
        TextSpan(
          children: [
            if (working > 0)
              TextSpan(text: '$working ${working == 1 ? 'set' : 'sets'}'),
            if (warmUp > 0)
              TextSpan(
                text: working > 0 ? ' + $warmUp warm-up' : '$warmUp warm-up',
                style: TextStyle(color: t.textTertiary),
              ),
          ],
        ),
        style: AppType.secondary(t),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: numberWidth,
            child: Text(
              '${index + 1}',
              style: AppType.mono(t, size: 13).copyWith(color: t.textTertiary),
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Text(
              exercise.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(t).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          sets,
        ],
      ),
    );
  }
}

/// A hairline between rows, starting where the exercise names do.
class _RowDivider extends ConsumerWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg + _ExerciseRow.numberWidth + _ExerciseRow.gap,
        right: AppSpacing.lg,
      ),
      child: Divider(height: 1, thickness: 1, color: t.divider),
    );
  }
}
