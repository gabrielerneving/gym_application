import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_model.dart';
import '../pages/active_workout_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import 'ui/ui.dart';

/// A saved workout program, rendered as a card on the home screen.
///
/// The whole card opens the program detail page; the trailing play button
/// starts the session (or resumes it, when this is the one running) and the
/// overflow button opens the options sheet.
class WorkoutWidget extends ConsumerWidget {
  final String title;

  /// Shown after the exercise count on the second line — e.g. when the
  /// program was last done. Empty to show the count alone.
  final String description;

  final int exerciseCount;
  final VoidCallback onMenuPressed;
  final VoidCallback? onStartWorkout;
  final VoidCallback? onTap;

  /// This program is the session currently running: the card says so and its
  /// action resumes rather than starts.
  final bool isLive;

  /// A start is in flight — the action shows progress instead of the button.
  final bool isStarting;

  const WorkoutWidget({
    super.key,
    required this.title,
    required this.description,
    required this.exerciseCount,
    required this.onMenuPressed,
    this.onStartWorkout,
    this.onTap,
    this.isLive = false,
    this.isStarting = false,
  });

  /// One fixed slot for the trailing action, whatever it says — "Start",
  /// "Resume" or a spinner — so the options button sits on the same line on
  /// every card and nothing shifts while a start is in flight.
  static const Size _actionSlot = Size(96, 38);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final detail = [
      exerciseCount == 1 ? '1 exercise' : '$exerciseCount exercises',
      description.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.heading(t),
                ),
                const SizedBox(height: AppSpacing.xxs),
                if (isLive)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: t.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm - 2),
                      Flexible(
                        child: Text(
                          'In progress',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.secondary(t).copyWith(
                            color: t.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.secondary(t),
                  ),
              ],
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
          const SizedBox(width: AppSpacing.xs),
          SizedBox.fromSize(size: _actionSlot, child: _action(t)),
        ],
      ),
    );
  }

  Widget _action(AppColors t) {
    if (isStarting) {
      return Center(
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: t.primary,
          ),
        ),
      );
    }

    if (isLive) {
      // The one gradient on the screen: the session you are in the middle of.
      return AppButton(
        label: 'Resume',
        size: AppButtonSize.small,
        onPressed: onStartWorkout,
      );
    }

    // Clearly a button — a filled, labelled surface — but neutral, so the
    // running session's Resume stays the only accent on the page.
    return Tooltip(
      message: 'Start workout',
      excludeFromSemantics: true,
      child: AppButton.secondary(
        label: 'Start',
        icon: Icons.play_arrow_rounded,
        size: AppButtonSize.small,
        onPressed: onStartWorkout,
      ),
    );
  }
}

/// Starts [program] — or, when a session is already running, takes you back
/// into it.
///
/// Only one workout can be live at a time (starting another would overwrite
/// it), so tapping a different program offers the running one instead of
/// dead-ending in an error.
///
/// [onBusy] brackets the moment the session is being prepared — it reads last
/// time's numbers first — so the caller can show progress on its button. It is
/// called with `false` even if the caller has since gone away, so guard any
/// `setState` with `mounted`. [replace] swaps the current route for the
/// workout, so finishing lands back on Home rather than on the page that
/// started it.
Future<void> launchProgram(
  BuildContext context,
  WidgetRef ref,
  WorkoutProgram program, {
  ValueChanged<bool>? onBusy,
  bool replace = false,
}) async {
  final active = ref.read(workoutProvider);

  if (active.isRunning) {
    final running = active.session;
    if (running != null && running.id == program.id) {
      _openActiveWorkout(context, replace: replace);
      return;
    }

    final runningTitle = running?.programTitle.trim() ?? '';
    final resume = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: runningTitle.isEmpty
          ? 'A workout is running'
          : '$runningTitle is running',
      message: 'Finish it before starting ${program.title}.',
      confirmLabel: 'Resume',
      cancelLabel: 'Not now',
      icon: Icons.play_arrow_rounded,
    );
    if (resume && context.mounted) {
      _openActiveWorkout(context, replace: replace);
    }
    return;
  }

  // An unfinished session from earlier would be overwritten by a new one —
  // open it instead, where it can be resumed or discarded.
  if (active.staleSession != null) {
    _openActiveWorkout(context, replace: replace);
    return;
  }

  onBusy?.call(true);
  var started = false;
  try {
    started = await ref.read(workoutProvider.notifier).startWorkout(program);
  } catch (error) {
    debugPrint('Could not start workout: $error');
  } finally {
    onBusy?.call(false);
  }

  if (!context.mounted) return;
  if (!started) {
    // Restoring a session the app was killed in won the race: show that one
    // rather than an error, and rather than overwriting it.
    final restored = ref.read(workoutProvider);
    if (restored.isRunning || restored.staleSession != null) {
      _openActiveWorkout(context, replace: replace);
      return;
    }
    AppSnack.show(
      context,
      ref,
      'Could not start the workout. Try again.',
      isError: true,
    );
    return;
  }
  // The pill appears the moment the session exists; if it was tapped in the
  // meantime the workout screen is already open — don't stack a second one.
  if (ModalRoute.of(context)?.isCurrent == false) return;
  _openActiveWorkout(context, replace: replace);
}

void _openActiveWorkout(BuildContext context, {bool replace = false}) {
  final route = MaterialPageRoute<void>(
    builder: (context) => const ActiveWorkoutScreen(),
  );
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}
