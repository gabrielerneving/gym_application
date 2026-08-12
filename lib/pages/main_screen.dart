import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'create_workout.dart';
import 'workout_history.dart';
import 'statistics_screen.dart';
import 'active_workout_screen.dart';
import '../providers/workout_provider.dart';
import '../providers/rest_timer_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/ui/ui.dart';

/// The app shell: four tabs behind a floating nav bar, plus the persistent
/// "workout in progress" pill that lets you jump back into a live session from
/// anywhere.
class MainScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MainScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _selectedIndex = widget.initialTabIndex;

  static const List<NavDestination> _destinations = [
    NavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    NavDestination(
      icon: Icons.add_circle_outline_rounded,
      activeIcon: Icons.add_circle_rounded,
      label: 'Create',
    ),
    NavDestination(
      icon: Icons.history_rounded,
      activeIcon: Icons.history_rounded,
      label: 'History',
    ),
    NavDestination(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      label: 'Stats',
    ),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Resume any workout that was left running.
    Future.delayed(Duration.zero, () {
      if (mounted) ref.read(workoutProvider.notifier).loadInitialState();
    });

    _pages = <Widget>[
      HomeScreen(onSwitchToProfileTab: () => _onTabTapped(3)),
      CreateWorkoutScreen(
        onWorkoutSaved: (index) => setState(() => _selectedIndex = index),
      ),
      const WorkoutHistoryScreen(),
      const StatisticsScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (index == _selectedIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final activeWorkout = ref.watch(workoutProvider);
    final isRunning = activeWorkout.isRunning;
    final topInset = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          HapticFeedback.selectionClick();
          _onTabTapped(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppThemeData.systemOverlayStyle(theme),
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          backgroundColor: theme.background,
          body: Stack(
            children: [
              // The pill is visually detached, but the content still yields the
              // strip it occupies: letting it overlay would put it straight on
              // top of every screen's title row and back button.
              AnimatedPadding(
                duration: AppMotion.normal,
                curve: AppMotion.standard,
                padding: EdgeInsets.only(top: isRunning ? 58 : 0),
                child: _FadeIndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),

              // Live workout pill: detached, centred and only as wide as its
              // content, matching the floating nav bar at the other end.
              Positioned(
                top: topInset + AppSpacing.sm,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: IgnorePointer(
                  ignoring: !isRunning,
                  child: AnimatedSlide(
                    duration: AppMotion.normal,
                    curve: AppMotion.spring,
                    offset: isRunning ? Offset.zero : const Offset(0, -1.6),
                    child: AnimatedOpacity(
                      duration: AppMotion.fast,
                      opacity: isRunning ? 1 : 0,
                      // A Row rather than Center: this Positioned has no
                      // bottom, so the vertical axis is loose and Center would
                      // stretch to the full stack height — which would make the
                      // slide-in animation travel 1.6 screens instead of 1.6
                      // pill heights.
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActiveWorkoutPill(
                            title:
                                activeWorkout.session?.programTitle ?? 'Workout',
                            elapsedSeconds: activeWorkout.elapsedSeconds,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ActiveWorkoutScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating nav bar.
              Align(
                alignment: Alignment.bottomCenter,
                child: FloatingNavBar(
                  currentIndex: _selectedIndex,
                  destinations: _destinations,
                  onTap: _onTabTapped,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An [IndexedStack] that cross-fades and gently scales when the index changes.
/// Keeps every tab alive — switching back to Statistics does not re-query.
class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _FadeIndexedStack({required this.index, required this.children});

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Driven via `drive` instead of `CurvedAnimation` — the latter attaches a
  // status listener to its parent on construction, so one per build leaks.
  late final Animation<double> _curved =
      _controller.drive(CurveTween(curve: AppMotion.enter));

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: (0.35 + 0.65 * t).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.985 + 0.015 * t,
            child: child,
          ),
        );
      },
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}

/// The frosted "workout in progress" pill with a live timer.
class _ActiveWorkoutPill extends ConsumerStatefulWidget {
  final String title;
  final int elapsedSeconds;
  final VoidCallback onTap;

  const _ActiveWorkoutPill({
    required this.title,
    required this.elapsedSeconds,
    required this.onTap,
  });

  @override
  ConsumerState<_ActiveWorkoutPill> createState() => _ActiveWorkoutPillState();
}

class _ActiveWorkoutPillState extends ConsumerState<_ActiveWorkoutPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _timer {
    final s = widget.elapsedSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStrength.none,
      scale: 0.97,
      child: GlassSurface(
        radius: AppRadius.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          // Hugs its content so the pill reads as a floating chip rather than
          // a full-width banner.
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final v = _pulse.value;
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: t.primaryGradientDiagonal,
                    boxShadow: [
                      BoxShadow(
                        color: t.primary.withValues(alpha: 0.25 + 0.25 * v),
                        blurRadius: 8 + 8 * v,
                        spreadRadius: v,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 19,
                    color: t.onPrimary,
                  ),
                );
              },
            ),
            const SizedBox(width: AppSpacing.md),
            // A ceiling rather than Expanded: the pill must not stretch, but a
            // long program name still has to give way instead of overflowing.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.heading(t).copyWith(fontSize: 15),
                  ),
                  _PillSubtitle(theme: t),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.primaryWash,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                _timer,
                style: AppType.mono(t, size: 14).copyWith(color: t.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pill's second line. Swaps to the live rest countdown while a rest is
/// running, so stepping away from the workout screen does not mean losing
/// track of it.
class _PillSubtitle extends ConsumerWidget {
  final AppColors theme;

  const _PillSubtitle({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rest = ref.watch(restTimerProvider);

    if (!rest.isRunning) {
      return Text(
        'In progress · tap to resume',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.caption(theme).copyWith(fontSize: 11.5),
      );
    }

    final tone = rest.isOvertime ? theme.success : theme.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 12, color: tone),
        const SizedBox(width: 4),
        Text(
          rest.isOvertime ? 'Rested ${rest.label}' : 'Resting ${rest.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption(theme).copyWith(fontSize: 11.5, color: tone),
        ),
      ],
    );
  }
}
