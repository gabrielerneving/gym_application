import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../providers/training_goals_provider.dart';
import 'ui/ui.dart';

/// ---------------------------------------------------------------------------
/// The editors for [TrainingGoals] — the weekly set band and the streak rule.
///
/// They live here rather than inside Settings because the numbers show up all
/// over the statistics screens, and a caption that reads "your 10–20 band"
/// should be able to open the thing that set it.
/// ---------------------------------------------------------------------------
class TrainingGoalSheets {
  TrainingGoalSheets._();

  /// The weekly working-set band each muscle group is scored against.
  static Future<void> weeklySetBand(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    return AppSheet.show<void>(
      context: context,
      ref: ref,
      title: 'Weekly sets per muscle',
      subtitle: 'The band your muscle volume is scored against',
      builder: (context) => const _BandEditor(),
    );
  }

  /// How many sessions a week have to be logged for the week to count.
  static Future<void> sessionsPerWeek(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    return AppSheet.show<void>(
      context: context,
      ref: ref,
      title: 'Sessions per week',
      subtitle: 'What it takes for a week to count toward your streak',
      builder: (context) => const _SessionsEditor(),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly set band
// ---------------------------------------------------------------------------

/// A range slider over the set band, with the common bands as one-tap presets.
///
/// The slider keeps its own value while a thumb is down and only writes to the
/// provider on release: every write re-scores the whole statistics layer, and
/// doing that on each of the forty steps of a drag is wasted work the user
/// would feel as lag.
class _BandEditor extends ConsumerStatefulWidget {
  const _BandEditor();

  @override
  ConsumerState<_BandEditor> createState() => _BandEditorState();
}

class _BandEditorState extends ConsumerState<_BandEditor> {
  RangeValues? _dragging;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final goals = ref.watch(trainingGoalsProvider);
    final notifier = ref.read(trainingGoalsProvider.notifier);

    final values =
        _dragging ?? RangeValues(goals.setsMin, goals.setsMax);
    final min = values.start.round();
    final max = values.end.round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BandReadout(min: min, max: max),
        const SizedBox(height: AppSpacing.lg),
        // Forty one-set steps drew forty dots along the track; the snapping
        // stays, the dots go.
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            overlayColor: t.primary.withValues(alpha: 0.12),
          ),
          child: RangeSlider(
            values: values,
            min: TrainingGoals.minSets.toDouble(),
            max: TrainingGoals.maxSets.toDouble(),
            divisions: TrainingGoals.maxSets - TrainingGoals.minSets,
            activeColor: t.primary,
            // The sheet is already the raised surface; the track needs the
            // hairline tone to show against it.
            inactiveColor: t.outline,
            onChanged: (next) {
              // Keep the ends at least a set apart, so the band never
              // collapses into a line that the charts cannot shade.
              if (next.end - next.start < TrainingGoals.minBandWidth) return;
              HapticFeedback.selectionClick();
              setState(() => _dragging = next);
            },
            onChangeEnd: (next) {
              setState(() => _dragging = null);
              notifier.setWeeklySetBand(next.start.round(), next.end.round());
            },
          ),
        ),
        Padding(
          // Lines the scale's ends up under the ends of the track.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${TrainingGoals.minSets}', style: AppType.caption(t)),
              Text('${TrainingGoals.maxSets}', style: AppType.caption(t)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('COMMON BANDS', style: AppType.overline(t)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final preset in SetBandPreset.all)
              AppChip(
                label: '${preset.label} · ${preset.min}–${preset.max}',
                selected: _dragging == null && preset.matches(goals),
                onTap: () {
                  setState(() => _dragging = null);
                  notifier.applyPreset(preset);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _GoalNote(text: _blurbFor(min, max)),
        if (!goals.isDefault) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.ghost(
              label: 'Reset to ${const TrainingGoals().bandLabel}',
              size: AppButtonSize.small,
              icon: Icons.restart_alt_rounded,
              onPressed: () {
                setState(() => _dragging = null);
                notifier.resetToDefaults();
              },
            ),
          ),
        ],
      ],
    );
  }

  /// The sentence under the slider. While a thumb is down it describes the
  /// value being dragged, which is the only way to judge a band before
  /// committing to it.
  static String _blurbFor(int min, int max) {
    for (final preset in SetBandPreset.all) {
      if (preset.min == min && preset.max == max) return preset.blurb;
    }
    return 'Under $min sets a week reads as below target, over $max as above. '
        'Anything between counts as on target.';
  }
}

/// The big "10 – 20" read-out at the top of the sheet.
class _BandReadout extends ConsumerWidget {
  final int min;
  final int max;

  const _BandReadout({required this.min, required this.max});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Both ends in body text: they are equals, and the slider below
            // already carries the accent for the selection.
            Text('$min', style: AppType.metric(t, size: 40)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                '–',
                style: AppType.metric(t, size: 28)
                    .copyWith(color: t.textSecondary),
              ),
            ),
            Text('$max', style: AppType.metric(t, size: 40)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('working sets per muscle, each week',
            style: AppType.caption(t), textAlign: TextAlign.center),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sessions per week
// ---------------------------------------------------------------------------

class _SessionsEditor extends ConsumerWidget {
  const _SessionsEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(trainingGoalsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var n = 1; n <= TrainingGoals.maxSessionsPerWeek; n++)
              AppChip(
                label: '$n',
                selected: goals.sessionsPerWeek == n,
                onTap: () => ref
                    .read(trainingGoalsProvider.notifier)
                    .setSessionsPerWeek(n),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _GoalNote(
          text: goals.sessionsPerWeek == 1
              ? 'Any week with a session logged keeps the streak alive.'
              : 'A week needs ${goals.sessionsLabel} before it counts. Weeks '
                  'below that break the streak.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settings rows
// ---------------------------------------------------------------------------

/// The Settings row for the weekly set band.
class WeeklySetBandTile extends ConsumerWidget {
  const WeeklySetBandTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(trainingGoalsProvider);

    return _GoalTile(
      icon: Icons.equalizer_rounded,
      title: 'Weekly sets per muscle',
      subtitle: 'What counts as on target in your volume stats',
      value: goals.bandLabel,
      onTap: () => TrainingGoalSheets.weeklySetBand(context, ref),
    );
  }
}

/// The Settings row for the streak rule.
class SessionsPerWeekTile extends ConsumerWidget {
  const SessionsPerWeekTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(trainingGoalsProvider);

    return _GoalTile(
      icon: Icons.local_fire_department_rounded,
      title: 'Sessions per week',
      subtitle: 'How many it takes for a week to count toward your streak',
      value: '${goals.sessionsPerWeek}',
      onTap: () => TrainingGoalSheets.sessionsPerWeek(context, ref),
    );
  }
}

/// Shared shape for the two goal rows: a value in mono type, then a chevron.
class _GoalTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  const _GoalTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppTile(
      bare: true,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppType.mono(t, size: 14).copyWith(color: t.primary),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
        ],
      ),
    );
  }
}

/// The explanatory paragraph at the foot of a goal sheet.
class _GoalNote extends ConsumerWidget {
  final String text;

  const _GoalNote({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(text, style: AppType.secondary(t)),
    );
  }
}
