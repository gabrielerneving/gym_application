import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/workout_session_model.dart';
import '../pages/workout_detail_page.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../services/analytics_service.dart';
import 'ui/ui.dart';

/// One completed session in the History list.
///
/// Purely presentational: every number comes from [AnalyticsService] so the
/// card, the statistics screens and the detail page agree on what a working
/// set and a tonne of volume are.
///
/// Tapping opens the detail page unless [onTap] overrides it. Deletion is owned
/// by the screen — it wires [onDelete] to the same confirm flow the swipe uses.
class WorkoutHistoryWidget extends ConsumerWidget {
  final WorkoutSession session;

  /// Defaults to pushing [WorkoutDetailPage].
  final VoidCallback? onTap;

  /// Long-press handler. Null hides the gesture entirely.
  final VoidCallback? onDelete;

  const WorkoutHistoryWidget({
    super.key,
    required this.session,
    this.onTap,
    this.onDelete,
  });

  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  /// Sets that beat the previous session — in reps or in load.
  static int progressionWins(WorkoutSession session) {
    var wins = 0;
    for (final exercise in session.completedExercises) {
      for (final set in exercise.sets) {
        final reps = set.progression ?? 0;
        final weight = set.weightProgression ?? 0.0;
        if (reps > 0 || weight > 0) wins++;
      }
    }
    return wins;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final showProgression = ref.watch(workoutSettingsProvider).showProgression;

    final volume = AnalyticsService.sessionVolume(session);
    final workingSets = AnalyticsService.sessionWorkingSets(session);
    final topSet = AnalyticsService.sessionTopSet(session);
    final wins = showProgression ? progressionWins(session) : 0;

    final names = session.completedExercises.map((e) => e.name).toList();
    final preview = names.isEmpty
        ? ''
        : names.take(3).join(' · ') +
            (names.length > 3 ? '   +${names.length - 3} more' : '');

    void open() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkoutDetailPage(session: session),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap ?? open,
      onLongPress: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.fitness_center_rounded,
                size: 42,
                iconSize: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session.programTitle.trim().isEmpty
                          ? 'Workout'
                          : session.programTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.heading(t),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${AppFormat.relativeDate(session.date)} · '
                      '${_dateFormat.format(session.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption(t),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: t.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: t.divider),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.schedule_rounded,
                  value: AppFormat.duration(session.durationInMinutes),
                  label: 'Time',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.repeat_rounded,
                  value: '$workingSets',
                  label: 'Sets',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.bolt_rounded,
                  value: '${AppFormat.compact(volume)} kg',
                  label: 'Volume',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.arrow_upward_rounded,
                  value: topSet > 0 ? '${AppFormat.weight(topSet)} kg' : '—',
                  label: 'Top set',
                ),
              ),
            ],
          ),
          if (preview.isNotEmpty || wins > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.secondary(t).copyWith(fontSize: 13),
                  ),
                ),
                if (wins > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(
                    label: '$wins up',
                    icon: Icons.trending_up_rounded,
                    color: t.success,
                    fontSize: 11,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A small icon + number + label stat, sized to sit four-across in a card.
class _MiniStat extends ConsumerWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: t.textTertiary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.mono(t, size: 14),
              ),
            ),
          ],
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
