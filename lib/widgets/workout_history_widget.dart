import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/workout_session_model.dart';
import '../pages/workout_detail_page.dart';
import '../providers/theme_provider.dart';
import 'ui/ui.dart';

/// One completed session in the History list.
///
/// Built to be scanned, not studied: the day sits in a fixed column on the
/// left; the program name shares its line with the duration and set count,
/// and the exercises run underneath so a past workout can be found by what
/// was in it. Two lines, not three, so a screen holds a week and a half of
/// training. The numbers live on the detail page.
///
/// A set counts once it has reps — weight 0 is a bodyweight set. Empty sets
/// and skipped exercises that older builds saved are ignored.
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

  static final DateFormat _weekdayFormat = DateFormat('EEE');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    var workingSets = 0;
    final names = <String>[];
    for (final exercise in session.completedExercises) {
      final logged = exercise.sets.where((s) => s.reps > 0).toList();
      if (logged.isEmpty) continue;
      workingSets += logged.where((s) => !s.isWarmUp).length;
      final name = exercise.name.trim();
      if (name.isNotEmpty) names.add(name);
    }

    final meta = [
      if (session.durationInMinutes > 0)
        AppFormat.duration(session.durationInMinutes),
      workingSets == 0
          ? 'No sets'
          : '$workingSets ${workingSets == 1 ? 'set' : 'sets'}',
    ].join(' · ');

    void open() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkoutDetailPage(session: session),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md + 2,
        AppSpacing.xl,
        AppSpacing.md + 2,
      ),
      onTap: onTap ?? open,
      onLongPress: onDelete,
      child: Row(
        children: [
          _DayStamp(
            day: session.date.day,
            weekday: _weekdayFormat.format(session.date),
          ),
          const SizedBox(width: AppSpacing.md),
          // A hairline keeps the date column reading as a column.
          Container(width: 1, height: 36, color: t.divider),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        session.programTitle.trim().isEmpty
                            ? 'Workout'
                            : session.programTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.heading(t),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      meta,
                      maxLines: 1,
                      style: AppType.mono(t, size: 13, weight: FontWeight.w600)
                          .copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
                if (names.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _ExercisePreview(
                    names: names,
                    style: AppType.secondary(t).copyWith(fontSize: 13),
                    moreStyle: AppType.secondary(t).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The exercises of a session on one line, cut at a whole name: as many as
/// fit, then "+N" for the rest — never "Overh…". Only when even the first
/// name does not fit is that one ellipsised, and the count still shows.
class _ExercisePreview extends StatelessWidget {
  final List<String> names;
  final TextStyle style;
  final TextStyle moreStyle;

  const _ExercisePreview({
    required this.names,
    required this.style,
    required this.moreStyle,
  });

  static const String _separator = ' · ';

  /// Air between the last name and the "+N".
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Measured with exactly what the Text widgets below will render with —
    // the inherited font included — or the cut lands in the wrong place.
    final inherited = DefaultTextStyle.of(context).style;

    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: inherited.merge(style)),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;

        // Most names first; the first count that fits wins.
        var shown = 1;
        for (var count = names.length; count >= 1; count--) {
          final rest = names.length - count;
          final needed = widthOf(names.take(count).join(_separator), style) +
              (rest == 0 ? 0 : _gap + widthOf('+$rest', moreStyle));
          if (needed <= max) {
            shown = count;
            break;
          }
        }

        final rest = names.length - shown;
        return Row(
          children: [
            Flexible(
              child: Text(
                names.take(shown).join(_separator),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: style,
              ),
            ),
            if (rest > 0) ...[
              const SizedBox(width: _gap),
              Text('+$rest', maxLines: 1, style: moreStyle),
            ],
          ],
        );
      },
    );
  }
}

/// Day of the month over a short weekday — the month itself is the header the
/// card sits under.
class _DayStamp extends ConsumerWidget {
  final int day;
  final String weekday;

  const _DayStamp({required this.day, required this.weekday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return SizedBox(
      width: 36,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$day', style: AppType.metric(t, size: 22)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            weekday.toUpperCase(),
            maxLines: 1,
            style: AppType.overline(t).copyWith(
              fontSize: 10.5,
              color: t.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
