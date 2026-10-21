import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/standard_workout_template.dart';
import '../models/workout_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';

/// "Beginner · 6 exercises · 1h 5m" — the one-line summary of a template,
/// shared by the template card and this page.
String templateSummary(StandardWorkoutTemplate template) {
  final count = template.exercises.length;
  final minutes = template.estimatedDurationMinutes;
  return <String>[
    template.category.trim(),
    '$count ${count == 1 ? 'exercise' : 'exercises'}',
    if (minutes > 0) AppFormat.duration(minutes),
  ].where((part) => part.isNotEmpty).join(' · ');
}

/// Whether the user already has a program copied from [template]. Copies keep
/// the template's title, so that is what is matched on.
bool isTemplateInPrograms(
  StandardWorkoutTemplate template,
  List<WorkoutProgram> programs,
) {
  final key = template.title.trim().toLowerCase();
  return programs.any((p) => p.title.trim().toLowerCase() == key);
}

/// Copies [template] into the signed-in user's programs and reports the
/// outcome with a snack. Returns true when the copy was saved.
Future<bool> addTemplateToMyWorkouts(
  BuildContext context,
  WidgetRef ref,
  StandardWorkoutTemplate template,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    AppSnack.show(context, ref, 'You need to be signed in.', isError: true);
    return false;
  }

  try {
    await DatabaseService(uid: user.uid).saveStandardWorkoutAsOwn(template);
    // The copy also files its exercises in the library, which statistics
    // read to map names to muscle groups.
    ref.invalidate(exerciseMuscleMapProvider);
    if (context.mounted) {
      AppSnack.show(context, ref, '${template.title} added to your workouts');
    }
    return true;
  } catch (e) {
    debugPrint('Could not add template ${template.id}: $e');
    if (context.mounted) {
      AppSnack.show(context, ref, 'Could not add the workout. Try again.',
          isError: true);
    }
    return false;
  }
}

/// A preview of one of the official workout templates, with the action that
/// copies it into the user's own programs.
class TemplateDetailPage extends ConsumerStatefulWidget {
  final StandardWorkoutTemplate template;

  const TemplateDetailPage({super.key, required this.template});

  @override
  ConsumerState<TemplateDetailPage> createState() =>
      _TemplateDetailPageState();
}

class _TemplateDetailPageState extends ConsumerState<TemplateDetailPage> {
  Stream<List<WorkoutProgram>>? _programs;
  bool _isAdding = false;

  /// Bridges the moment between a successful copy and the programs stream
  /// catching up with it.
  bool _justAdded = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _programs = DatabaseService(uid: user.uid).getWorkoutPrograms();
    }
  }

  Future<void> _add() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    final ok = await addTemplateToMyWorkouts(context, ref, widget.template);
    if (!mounted) return;
    setState(() {
      _isAdding = false;
      _justAdded = ok;
    });
  }

  /// Target muscles and coaching notes — only offered for exercises that
  /// actually carry some.
  void _showExerciseDetails(StandardExercise exercise) {
    final t = ref.read(themeProvider);
    final muscles = exercise.muscleGroups ?? const <String>[];
    final notes = (exercise.notes ?? '').trim();

    AppSheet.show<void>(
      context: context,
      ref: ref,
      title: exercise.name,
      subtitle: _setsLabel(exercise),
      builder: (context) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (muscles.isNotEmpty) ...[
              const Overline('Targets'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final muscle in muscles) AppBadge(label: muscle),
                ],
              ),
            ],
            if (muscles.isNotEmpty && notes.isNotEmpty)
              const SizedBox(height: AppSpacing.xl),
            if (notes.isNotEmpty) ...[
              const Overline('Notes'),
              Text(notes, style: AppType.body(t).copyWith(height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  static String _setsLabel(StandardExercise exercise) {
    final working = exercise.workingSets;
    final base = '$working ${working == 1 ? 'set' : 'sets'}';
    return exercise.warmUpSets > 0
        ? '$base · ${exercise.warmUpSets} warm-up'
        : base;
  }

  static bool _hasDetails(StandardExercise exercise) =>
      (exercise.muscleGroups?.isNotEmpty ?? false) ||
      (exercise.notes?.trim().isNotEmpty ?? false);

  Widget _addButton() {
    return StreamBuilder<List<WorkoutProgram>>(
      stream: _programs,
      builder: (context, snapshot) {
        final programs = snapshot.data ?? const <WorkoutProgram>[];
        final added =
            _justAdded || isTemplateInPrograms(widget.template, programs);

        if (added) {
          return const AppButton.secondary(
            label: 'In your workouts',
            icon: Icons.check_rounded,
            expand: true,
            onPressed: null,
          );
        }
        return AppButton(
          label: 'Add to my workouts',
          icon: Icons.add_rounded,
          expand: true,
          loading: _isAdding,
          onPressed: _isAdding ? null : _add,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final template = widget.template;
    final exercises = template.exercises;

    if (exercises.isEmpty) {
      return AppScaffold(
        title: template.title,
        bottomPadding: AppSpacing.xxxl,
        body: EmptyState(
          icon: Icons.fitness_center_rounded,
          title: 'Nothing in this template',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final description = template.description.trim();

    return AppScaffold(
      title: template.title,
      subtitle: templateSummary(template),
      bottomPadding: AppSpacing.xxxl,
      children: [
        if (description.isNotEmpty) ...[
          FadeSlideIn(
            child: Text(
              description,
              style: AppType.body(t).copyWith(
                color: t.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        FadeSlideIn(index: 1, child: _addButton()),
        const SectionHeader(title: 'Exercises'),
        for (var i = 0; i < exercises.length; i++)
          FadeSlideIn(
            index: i,
            child: _TemplateExerciseRow(
              name: exercises[i].name,
              setsLabel: _setsLabel(exercises[i]),
              onTap: _hasDetails(exercises[i])
                  ? () => _showExerciseDetails(exercises[i])
                  : null,
            ),
          ),
      ],
    );
  }
}

/// One row in the template's exercise list — the same shape as a row in the
/// workout builder, with a chevron only when there is more to see.
class _TemplateExerciseRow extends ConsumerWidget {
  final String name;
  final String setsLabel;
  final VoidCallback? onTap;

  const _TemplateExerciseRow({
    required this.name,
    required this.setsLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppType.heading(t),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(setsLabel, style: AppType.secondary(t)),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: t.textTertiary,
            ),
          ],
        ],
      ),
    );
  }
}
