import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/standard_workout_template.dart';
import '../providers/theme_provider.dart';
import '../widgets/ui/ui.dart';

/// A read-only preview of one of the official workout templates, before the
/// user copies it into their own programs.
class TemplateDetailPage extends ConsumerWidget {
  final StandardWorkoutTemplate template;

  const TemplateDetailPage({super.key, required this.template});

  String? get _subtitle {
    final parts = [
      template.type,
      template.category,
    ].where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// The per-exercise detail sheet: target muscles, the set split and any
  /// coaching notes attached to the template.
  void _showExerciseDetails(
    BuildContext context,
    WidgetRef ref,
    StandardExercise exercise,
  ) {
    final t = ref.read(themeProvider);
    final muscles = exercise.muscleGroups ?? const <String>[];
    final notes = exercise.notes ?? '';

    AppSheet.show<void>(
      context: context,
      ref: ref,
      title: exercise.name,
      builder: (context) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (muscles.isNotEmpty) ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final muscle in muscles) AppBadge(label: muscle),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            AppCard(
              inset: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Overline('Sets & reps'),
                  MetricRow(
                    label: 'Warm-up sets',
                    value: '${exercise.warmUpSets}',
                    icon: Icons.local_fire_department_rounded,
                  ),
                  MetricRow(
                    label: 'Working sets',
                    value: '${exercise.workingSets}',
                    icon: Icons.fitness_center_rounded,
                  ),
                  MetricRow(
                    label: 'Total sets',
                    value: '${exercise.sets}',
                    icon: Icons.format_list_numbered_rounded,
                  ),
                ],
              ),
            ),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                color: t.primaryWash,
                border: Border.all(color: t.primaryWashOutline),
                shadow: const [],
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          size: 18,
                          color: t.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Training tips',
                          style: AppType.heading(t).copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      notes,
                      style: AppType.body(t).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final exercises = template.exercises;

    if (exercises.isEmpty) {
      return AppScaffold(
        title: template.title,
        subtitle: _subtitle,
        body: EmptyState(
          icon: Icons.fitness_center_rounded,
          title: 'Nothing in this template',
          message: 'This template has no exercises yet.',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    return AppScaffold(
      title: template.title,
      subtitle: _subtitle,
      children: [
        FadeSlideIn(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (template.description.trim().isNotEmpty) ...[
                  Text(
                    template.description,
                    style: AppType.body(t).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (template.type.trim().isNotEmpty)
                      AppBadge(
                        label: template.type,
                        icon: Icons.category_rounded,
                      ),
                    AppBadge(
                      label: '${template.estimatedDurationMinutes} min',
                      icon: Icons.schedule_rounded,
                      color: t.textSecondary,
                    ),
                    AppBadge(
                      label: '${exercises.length} '
                          '${exercises.length == 1 ? 'exercise' : 'exercises'}',
                      icon: Icons.fitness_center_rounded,
                      color: t.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SectionHeader(
          title: 'Exercises',
          subtitle: 'Tap one for target muscles, sets and tips',
        ),
        for (var i = 0; i < exercises.length; i++)
          FadeSlideIn(
            index: i,
            child: _TemplateExerciseCard(
              exercise: exercises[i],
              index: i,
              onTap: () => _showExerciseDetails(context, ref, exercises[i]),
            ),
          ),
      ],
    );
  }
}

/// One row in the template's exercise list.
class _TemplateExerciseCard extends ConsumerWidget {
  final StandardExercise exercise;
  final int index;
  final VoidCallback onTap;

  const _TemplateExerciseCard({
    required this.exercise,
    required this.index,
    required this.onTap,
  });

  /// A, B, C … and plain numbers once the alphabet runs out.
  String get _marker =>
      index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.primaryWash,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: t.primaryWashOutline),
            ),
            child: Text(
              _marker,
              style: AppType.mono(t, size: 14, weight: FontWeight.w800)
                  .copyWith(color: t.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exercise.name,
                  style: AppType.heading(t),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppBadge(
                      label: '${exercise.workingSets} working',
                      icon: Icons.fitness_center_rounded,
                    ),
                    if (exercise.warmUpSets > 0)
                      AppBadge(
                        label: '${exercise.warmUpSets} warm-up',
                        icon: Icons.local_fire_department_rounded,
                        color: t.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: t.primary,
            ),
          ),
        ],
      ),
    );
  }
}
