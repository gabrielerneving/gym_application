import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/admin_config.dart';
import '../models/workout_model.dart';
import '../models/workout_session_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';
import '../widgets/workout_widget.dart';
import 'admin_screen.dart';
import 'create_workout.dart';
import 'program_detail_page.dart';

/// The front page: this week at a glance, then every saved program, each one
/// a single tap away from a live session.
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToProfileTab;

  /// Opens the Create tab — the empty state's way forward. Without it the
  /// builder is pushed as a route instead.
  final VoidCallback? onSwitchToCreateTab;

  const HomeScreen({
    super.key,
    this.onSwitchToProfileTab,
    this.onSwitchToCreateTab,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _title = 'My workouts';

  /// Bumped to rebuild the program subscription after a failure.
  int _retryToken = 0;

  /// The live programs query, kept across builds. A fresh stream per build
  /// makes StreamBuilder resubscribe — flashing the skeleton and opening
  /// another Firestore listener — every time anything on this screen changes.
  Stream<List<WorkoutProgram>>? _programs;
  String? _programsUid;
  int? _programsToken;

  /// The program whose session is being prepared, if any.
  String? _startingId;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Stream<List<WorkoutProgram>> _programsFor(String uid) {
    if (_programs == null ||
        _programsUid != uid ||
        _programsToken != _retryToken) {
      _programsUid = uid;
      _programsToken = _retryToken;
      _programs = DatabaseService(uid: uid).getWorkoutPrograms();
    }
    return _programs!;
  }

  /// Admin panel is gated on the signed-in address.
  bool _isAdminUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return AdminConfig.isAdminEmail(user.email ?? '');
  }

  void _openCreate() {
    final switchTab = widget.onSwitchToCreateTab;
    if (switchTab != null) {
      switchTab();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateWorkoutScreen()),
    );
  }

  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AdminScreen()),
    );
  }

  void _openDetail(WorkoutProgram program) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProgramDetailPage(program: program),
      ),
    );
  }

  /// The overflow menu on a program card.
  void _showWorkoutOptions(WorkoutProgram program, DatabaseService dbService) {
    AppSheet.actions(
      context: context,
      ref: ref,
      title: program.title,
      actions: [
        SheetAction(
          icon: Icons.edit_rounded,
          label: 'Edit',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    CreateWorkoutScreen(workoutToEdit: program),
              ),
            );
          },
        ),
        SheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          destructive: true,
          onTap: () => _deleteProgram(program, dbService),
        ),
      ],
    );
  }

  Future<void> _deleteProgram(
    WorkoutProgram program,
    DatabaseService dbService,
  ) async {
    final shouldDelete = await AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Delete "${program.title}"?',
      message: 'This cannot be undone. Workouts you have logged with it stay '
          'in your history.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!shouldDelete || !mounted) return;

    try {
      await dbService.deleteWorkoutProgram(program.id);
    } catch (_) {
      if (!mounted) return;
      AppSnack.show(
        context,
        ref,
        'Could not delete "${program.title}". Try again.',
        isError: true,
      );
    }
  }

  void _startWorkout(WorkoutProgram program) {
    // One start at a time — a second tap while the first is still preparing
    // would race it.
    if (_startingId != null) return;
    launchProgram(
      context,
      ref,
      program,
      onBusy: (busy) {
        if (mounted) setState(() => _startingId = busy ? program.id : null);
      },
    );
  }

  /// "3 days ago" — when the program was last done, or nothing if never.
  String _lastDone(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    // A session stamped by a phone whose clock ran ahead still reads "Today".
    return AppFormat.relativeDate(date.isAfter(now) ? now : date, now: now);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Säkerhetskoll ifall något skulle gå fel och vi inte har ett UID.
    if (uid == null) {
      return AppScaffold(
        title: _title,
        body: ErrorState(
          message: 'Could not find user. Please log in again.',
          onRetry: () => setState(() => _retryToken++),
        ),
      );
    }

    final dbService = DatabaseService(uid: uid);

    // The running session's program, so its card can offer "Resume".
    final liveId = ref.watch(
      workoutProvider.select((s) => s.isRunning ? s.session?.id : null),
    );

    // When each program was last done, keyed by title like the history is.
    final usage = ref.watch(trainingDataProvider).valueOrNull?.programs ??
        const <ProgramUsage>[];
    final lastDone = <String, DateTime>{
      for (final u in usage) u.title: u.lastPerformed,
    };

    final actions = <Widget>[
      if (_isAdminUser())
        AppIconButton(
          icon: Icons.admin_panel_settings_rounded,
          tooltip: 'Admin Panel (Add Templates)',
          onPressed: _openAdmin,
        ),
    ];

    // StreamBuilder för att hämta och visa data i realtid
    return StreamBuilder<List<WorkoutProgram>>(
      // A new key on retry gives a fresh snapshot instead of carrying the old
      // error over into the new subscription.
      key: ValueKey<int>(_retryToken),
      stream: _programsFor(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppScaffold(
            title: _title,
            subtitle: _greeting,
            actions: actions,
            body: ErrorState(
              message: 'Your workouts could not be loaded.',
              onRetry: () => setState(() => _retryToken++),
            ),
          );
        }

        // Medan vi väntar på data från Firebase, visa skelett i listans form
        if (!snapshot.hasData) {
          return AppScaffold(
            title: _title,
            subtitle: _greeting,
            actions: actions,
            children: const [
              SkeletonCard(height: _cardHeight),
              SizedBox(height: AppSpacing.xxl),
              SkeletonCard(height: _cardHeight),
              SizedBox(height: AppSpacing.md),
              SkeletonCard(height: _cardHeight),
              SizedBox(height: AppSpacing.md),
              SkeletonCard(height: _cardHeight),
            ],
          );
        }

        // Firestore hands documents back in id order — random uuids, so new
        // programs landed anywhere. Alphabetical is at least predictable.
        final programs = [...snapshot.data!]..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );

        if (programs.isEmpty) {
          return AppScaffold(
            title: _title,
            subtitle: _greeting,
            actions: actions,
            body: EmptyState(
              icon: Icons.fitness_center_rounded,
              title: 'No workouts yet',
              message: 'Build a program once, then start it with a single '
                  'tap every time you train.',
              actionLabel: 'Create a workout',
              onAction: _openCreate,
            ),
          );
        }

        return AppScaffold(
          title: _title,
          subtitle: _greeting,
          actions: actions,
          children: [
            _WeekCard(onTap: widget.onSwitchToProfileTab),
            for (var i = 0; i < programs.length; i++)
              FadeSlideIn(
                // Keyed so a card keeps its place (and a new program is the
                // one that fades in) when the sorted list shifts.
                key: ValueKey<String>(programs[i].id),
                index: i,
                child: WorkoutWidget(
                  title: programs[i].title,
                  description: _lastDone(lastDone[programs[i].title]),
                  exerciseCount: programs[i].exercises.length,
                  isLive: liveId != null && liveId == programs[i].id,
                  isStarting: _startingId == programs[i].id,
                  onMenuPressed: () =>
                      _showWorkoutOptions(programs[i], dbService),
                  onStartWorkout: () => _startWorkout(programs[i]),
                  onTap: () => _openDetail(programs[i]),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Roughly the height of a program card and of the week card, so the
  /// skeleton does not jump when the real content lands.
  static const double _cardHeight = 76;
}

/// This week at a glance: sessions logged against the weekly goal, and which
/// days they fell on. Tapping through opens Statistics.
class _WeekCard extends ConsumerWidget {
  final VoidCallback? onTap;

  const _WeekCard({this.onTap});

  /// M T W T F S S — the strip runs Monday to Sunday, the same week the count
  /// beside it covers.
  static final List<String> _labels = [
    for (final day in AppFormat.weekdaysShort) day.substring(0, 1),
  ];

  /// Whether a session was logged on each day of the current week.
  static List<bool> _thisWeek(List<WorkoutSession> sessions) {
    final start = AnalyticsService.weekStart(DateTime.now());
    final trained = {for (final s in sessions) AnalyticsService.dayOf(s.date)};
    return [
      // Calendar arithmetic rather than `add(Duration(days: i))`, which lands
      // an hour off midnight across a daylight-saving change.
      for (var i = 0; i < 7; i++)
        trained.contains(DateTime(start.year, start.month, start.day + i)),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final training = ref.watch(trainingDataProvider);

    const spacing = EdgeInsets.only(bottom: AppSpacing.xxl);

    return training.when(
      loading: () => const Padding(
        padding: spacing,
        child: SkeletonCard(height: _HomeScreenState._cardHeight),
      ),
      error: (error, _) => Padding(
        padding: spacing,
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 18, color: t.textTertiary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Your week could not be loaded',
                  style: AppType.secondary(t),
                ),
              ),
              AppButton.ghost(
                label: 'Retry',
                size: AppButtonSize.small,
                onPressed: () => ref.invalidate(workoutSessionsProvider),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        // Nothing logged yet: an empty week says nothing the empty history
        // does not, so the programs get the screen to themselves.
        if (data.isEmpty) return const SizedBox.shrink();

        final done = data.streak.thisWeek;
        // A goal of one is the default "any session counts", not a target.
        final goal = data.goals.sessionsPerWeek;
        final hasGoal = goal > 1;
        final reached = hasGoal && done >= goal;
        // Monday = 0. Today is marked, the days still to come are quieter.
        final today = DateTime.now().weekday - 1;

        // "2 workouts" on its own, "2/4" against a goal — the number always
        // says what it counts. (With a goal the unit would crowd the strip,
        // and "of 4" already says it.)
        final unit = hasGoal ? null : (done == 1 ? 'workout' : 'workouts');

        return Padding(
          padding: spacing,
          child: FadeSlideIn(
            child: AppCard(
              onTap: onTap,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This week',
                        style: AppType.caption(t)
                            .copyWith(color: t.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          CountUp(
                            value: done.toDouble(),
                            style: AppType.metric(t, size: 26).copyWith(
                              color: reached ? t.success : null,
                            ),
                          ),
                          if (hasGoal)
                            Text(
                              '/$goal',
                              style: AppType.mono(t, size: 15).copyWith(
                                color: t.textSecondary,
                              ),
                            ),
                          if (unit != null) ...[
                            const SizedBox(width: AppSpacing.xs + 1),
                            Text(unit, style: AppType.secondary(t)),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _WeekDays(
                      trained: _thisWeek(data.sessions),
                      labels: _labels,
                      today: today,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Monday to Sunday as a row of dots: done days carry a check in the success
/// colour, today has a ring around it, and the days still to come are drawn
/// quieter than the ones already past — so a glance says where in the week
/// you are, not only what you did.
class _WeekDays extends ConsumerWidget {
  final List<bool> trained;
  final List<String> labels;

  /// Index of today in [trained], Monday = 0.
  final int today;

  const _WeekDays({
    required this.trained,
    required this.labels,
    required this.today,
  });

  static const double _dot = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < trained.length; i++)
          _day(t, i, done: trained[i], isToday: i == today, future: i > today),
      ],
    );
  }

  Widget _day(
    AppColors t,
    int i, {
    required bool done,
    required bool isToday,
    required bool future,
  }) {
    final Color fill;
    final Border? border;
    if (done) {
      fill = t.success.withValues(alpha: t.isDark ? 0.18 : 0.14);
      border = Border.all(
        color: t.success.withValues(alpha: isToday ? 1 : 0.45),
        width: isToday ? 1.6 : 1,
      );
    } else if (isToday) {
      fill = t.surface;
      border = Border.all(color: t.text, width: 1.6);
    } else if (future) {
      fill = Colors.transparent;
      border = Border.all(color: t.outline);
    } else {
      fill = t.surface;
      border = Border.all(color: t.outline);
    }

    final labelStyle = AppType.caption(t).copyWith(
      fontSize: 11,
      color: isToday
          ? t.text
          : future
              ? t.textTertiary
              : t.textSecondary,
      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: border,
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 15, color: t.success)
              : null,
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(i < labels.length ? labels[i] : '', style: labelStyle),
      ],
    );
  }
}
