import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'ui/ui.dart';

/// A saved workout program, rendered as a card on the home screen.
///
/// The whole card opens the program detail page; the trailing "Start" button
/// launches the session and the overflow button opens the options sheet.
class WorkoutWidget extends ConsumerWidget {
  final String title;
  final String description;
  final int exerciseCount;
  final VoidCallback onMenuPressed;
  final VoidCallback? onStartWorkout;
  final VoidCallback? onTap;

  const WorkoutWidget({
    super.key,
    required this.title,
    required this.description,
    required this.exerciseCount,
    required this.onMenuPressed,
    this.onStartWorkout,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final subtitle = description.trim();

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.title(t).copyWith(fontSize: 19),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppIconButton(
                icon: Icons.more_horiz_rounded,
                onPressed: onMenuPressed,
                filled: false,
                size: 36,
                iconSize: 20,
                color: t.textSecondary,
                tooltip: 'Workout options',
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.secondary(t),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Row(
              children: [
                AppBadge(
                  label: exerciseCount == 1
                      ? '1 exercise'
                      : '$exerciseCount exercises',
                  icon: Icons.fitness_center_rounded,
                ),
                const Spacer(),
                AppButton(
                  label: 'Start',
                  icon: Icons.play_arrow_rounded,
                  size: AppButtonSize.small,
                  onPressed: onStartWorkout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
