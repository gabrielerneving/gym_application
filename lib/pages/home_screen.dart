import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/admin_config.dart';
import '../models/workout_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';
import '../widgets/workout_widget.dart';
import 'active_workout_screen.dart';
import 'admin_screen.dart';
import 'create_workout.dart';
import 'program_detail_page.dart';

/// The front page: a compact snapshot of the training week followed by every
/// saved program, each one a single tap away from a live session.
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToProfileTab;

  const HomeScreen({super.key, this.onSwitchToProfileTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Bumped to rebuild the program subscription after a failure.
  int _retryToken = 0;

  static const String _title = 'My workouts';

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// Admin panel is gated on the signed-in address.
  bool _isAdminUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return AdminConfig.isAdminEmail(user.email ?? '');
  }

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateWorkoutScreen()),
    );
  }

  void _openAdmin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AdminScreen()),
    );
  }

  /// The overflow menu on a program card.
  void _showWorkoutOptions(
    BuildContext context,
    WorkoutProgram program,
    DatabaseService dbService,
  ) {
    AppSheet.actions(
      context: context,
      ref: ref,
      title: program.title,
      actions: [
        SheetAction(
          icon: Icons.edit_rounded,
          label: 'Edit',
          description: 'Change the name, exercises or sets',
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
          description: 'Remove this workout permanently',
          destructive: true,
          onTap: () async {
            final shouldDelete = await AppDialog.confirm(
              context: context,
              ref: ref,
              title: 'Delete workout?',
              message:
                  'Are you sure you want to delete "${program.title}"? '
                  'This action cannot be undone.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (shouldDelete) {
              await dbService.deleteWorkoutProgram(program.id);
            }
          },
        ),
      ],
    );
  }

  void _showActiveWorkoutDialog(BuildContext context) {
    AppDialog.info(
      context: context,
      ref: ref,
      title: 'Workout already active',
      message:
          'You already have an active workout in progress. Please finish or '
          'cancel your current workout before starting a new one.',
      buttonLabel: 'Got it',
      icon: Icons.bolt_rounded,
    );
  }

  void _startWorkout(BuildContext context, WorkoutProgram program) {
    // Bara ett pass åt gången — annars skrivs den pågående sessionen över.
    final activeWorkout = ref.read(workoutProvider);
    if (activeWorkout.isRunning) {
      _showActiveWorkoutDialog(context);
      return;
    }

    ref.read(workoutProvider.notifier).startWorkout(program);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ActiveWorkoutScreen()),
    );
  }

  /// "Bench Press, Row, Squat …" — a quiet preview of what the program holds.
  String _describe(WorkoutProgram program) {
    final names = program.exercises.map((e) => e.name).toList();
    if (names.isEmpty) return '';
    final preview = names.take(3).join(', ');
    return names.length > 3 ? '$preview …' : preview;
  }

  Widget _programCard(
    BuildContext context,
    DatabaseService dbService,
    WorkoutProgram program,
    int index,
  ) {
    return FadeSlideIn(
      index: index,
      child: WorkoutWidget(
        title: program.title,
        description: _describe(program),
        exerciseCount: program.exercises.length,
        onMenuPressed: () => _showWorkoutOptions(context, program, dbService),
        onStartWorkout: () => _startWorkout(context, program),
        onTap: () {
          // Visa programstrukturen utan tidigare data
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProgramDetailPage(program: program),
            ),
          );
        },
      ),
    );
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

    // Skapa en instans av vår DatabaseService
    final dbService = DatabaseService(uid: uid);

    final actions = <Widget>[
      if (_isAdminUser())
        AppIconButton(
          icon: Icons.admin_panel_settings_rounded,
          tooltip: 'Admin Panel (Add Templates)',
          onPressed: () => _openAdmin(context),
        ),
    ];

    // StreamBuilder för att hämta och visa data i realtid
    return StreamBuilder<List<WorkoutProgram>>(
      key: ValueKey<int>(_retryToken),
      stream: dbService.getWorkoutPrograms(),
      builder: (context, snapshot) {
        // Om ett fel inträffade
        if (snapshot.hasError) {
          return AppScaffold(
            title: _title,
            subtitle: _greeting,
            actions: actions,
            body: ErrorState(
              message: 'Something went wrong: ${snapshot.error}',
              onRetry: () => setState(() => _retryToken++),
            ),
          );
        }

        // Medan vi väntar på data från Firebase, visa skelett i listans form
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppScaffold(
            title: _title,
            subtitle: _greeting,
            actions: actions,
            children: const [
              SkeletonCard(height: 156),
              SizedBox(height: AppSpacing.xxxl),
              SkeletonCard(height: 132),
              SizedBox(height: AppSpacing.md),
              SkeletonCard(height: 132),
              SizedBox(height: AppSpacing.md),
              SkeletonCard(height: 132),
            ],
          );
        }

        final programs = snapshot.data ?? const <WorkoutProgram>[];

        // Om vi har data, men listan är tom
        if (programs.isEmpty) {
          return AppScaffold(
            title: _title,
            subtitle: _greeting,
            actions: actions,
            body: EmptyState(
              icon: Icons.fitness_center_rounded,
              title: 'No workouts yet',
              message:
                  'Build a program once, then start it with a single tap every '
                  'time you train.',
              actionLabel: 'Create your first workout',
              onAction: () => _openCreate(context),
            ),
          );
        }

        return AppScaffold(
          title: _title,
          subtitle: '$_greeting · ${programs.length} '
              '${programs.length == 1 ? 'program' : 'programs'} saved',
          actions: actions,
          children: [
            _TodayStrip(onTap: widget.onSwitchToProfileTab),
            const SectionHeader(title: 'Your programs'),
            for (var i = 0; i < programs.length; i++)
              _programCard(context, dbService, programs[i], i),
          ],
        );
      },
    );
  }
}

/// One card summarising the training week: the current weekly streak, how many
/// sessions have been logged this week and the last seven days at a glance.
class _TodayStrip extends ConsumerWidget {
  final VoidCallback? onTap;

  const _TodayStrip({this.onTap});

  /// Mon–Sun labels ending on today, matching [TrainingData.lastSevenDays].
  List<String> _labels() {
    final today = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        AppFormat.weekdaysShort[
            today.subtract(Duration(days: i)).weekday - 1],
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final training = ref.watch(trainingDataProvider);

    return training.when(
      loading: () => const SkeletonCard(height: 156),
      error: (error, _) => AppCard(
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
      data: (data) {
        final streak = data.streak;

        return FadeSlideIn(
          child: AppCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Current streak',
                        value: streak.current,
                        unit: streak.current == 1 ? 'week' : 'weeks',
                        color: t.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(width: 1, height: 38, color: t.divider),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _MiniMetric(
                        icon: Icons.bolt_rounded,
                        label: 'This week',
                        value: streak.thisWeek,
                        unit: streak.thisWeek == 1 ? 'session' : 'sessions',
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: t.textTertiary,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(height: 1, thickness: 1, color: t.divider),
                const SizedBox(height: AppSpacing.lg),
                WeekStrip(
                  days: data.lastSevenDays,
                  labels: _labels(),
                  dotSize: 28,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A small icon + number + label block used inside the week card.
class _MiniMetric extends ConsumerWidget {
  final IconData icon;
  final String label;
  final int value;
  final String unit;
  final Color? color;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = color ?? t.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: tone),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption(t),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            CountUp(
              value: value.toDouble(),
              style: AppType.metric(t, size: 24),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption(t),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
