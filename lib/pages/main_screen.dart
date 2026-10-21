import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'create_workout.dart';
import 'workout_history.dart';
import 'statistics_screen.dart';
import 'active_workout_screen.dart';
import '../models/workout_session_model.dart';
import '../providers/workout_provider.dart';
import '../providers/rest_timer_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/placeholder_history.dart';
import '../widgets/ui/ui.dart';

/// The app shell: four tabs behind a floating nav bar, plus the live-workout
/// pill that floats just above the bar while a session is running, so you can
/// jump back into it from anywhere.
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
      HomeScreen(
        onSwitchToProfileTab: () => _onTabTapped(3),
        onSwitchToCreateTab: () => _onTabTapped(1),
      ),
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

  void _openActiveWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    // Only the on/off state — the pill watches the ticking timer itself, so
    // the shell does not rebuild every second. A session left running for
    // too long comes back "stale" rather than running; the pill is the only
    // way to reach the screen that offers to resume or discard it.
    final hasSession = ref.watch(
      workoutProvider.select((s) => s.isRunning || s.staleSession != null),
    );
    // Read here, above the Scaffold: a Scaffold body never sees the keyboard.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showPill = hasSession && !keyboardOpen;

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
          // The tabs deal with the keyboard themselves: AppScaffold resizes its
          // own body, and the nav bar and Create's save bar get out of its way.
          // Resizing here as well strips the keyboard inset before any of them
          // can see it — which is what left the nav bar riding on top of it.
          resizeToAvoidBottomInset: false,
          backgroundColor: theme.background,
          body: Stack(
            children: [
              _BottomClearance(
                extra: showPill ? NavBarMetrics.accessoryClearance : 0,
                child: _FadeIndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),

              // Painted before the bar so it rises out from behind it.
              _LiveWorkoutAccessory(
                visible: showPill,
                tabCount: _destinations.length,
                onTap: _openActiveWorkout,
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: FloatingNavBar(
                  currentIndex: _selectedIndex,
                  destinations: _destinations,
                  onTap: _onTabTapped,
                  visible: !keyboardOpen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grows the bottom safe-area inset seen by everything below it by [extra].
///
/// Tab pages already end their scroll views with `padding.bottom` plus the
/// nav-bar clearance, so growing the inset is all it takes for every tab — and
/// anything a tab anchors above the bar — to clear the live-workout pill too.
/// No page needs to know the pill exists. The nav bar sits outside this and
/// keeps reading the real inset.
class _BottomClearance extends StatelessWidget {
  final double extra;
  final Widget child;

  const _BottomClearance({required this.extra, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: extra),
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      child: child,
      // Always wrapped, even at 0: swapping the MediaQuery in and out would
      // change the tree shape and remount every tab.
      builder: (context, value, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(
              bottom: media.padding.bottom + value,
            ),
            viewPadding: media.viewPadding.copyWith(
              bottom: media.viewPadding.bottom + value,
            ),
          ),
          child: child!,
        );
      },
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

/// Positions the live-workout pill just above the nav bar, like a detached
/// mini-player, and tucks it down behind the bar when it is not needed.
class _LiveWorkoutAccessory extends StatelessWidget {
  final bool visible;
  final int tabCount;
  final VoidCallback onTap;

  const _LiveWorkoutAccessory({
    required this.visible,
    required this.tabCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Same inset the nav bar measures from, so the gap between them is exact.
    final bottom = MediaQuery.viewPaddingOf(context).bottom +
        NavBarMetrics.totalHeight +
        NavBarMetrics.accessoryGap;

    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      bottom: bottom,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          // Far enough to sink fully behind the bar, so it reads as rising out
          // of it rather than fading in mid-air.
          child: AnimatedSlide(
            duration: AppMotion.normal,
            curve: visible ? AppMotion.spring : AppMotion.exit,
            offset: visible ? Offset.zero : const Offset(0, 1.3),
            child: AnimatedScale(
              duration: AppMotion.normal,
              curve: visible ? AppMotion.spring : AppMotion.exit,
              scale: visible ? 1 : 0.92,
              child: AnimatedOpacity(
                duration: AppMotion.fast,
                opacity: visible ? 1 : 0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The Positioned has no top, so the height is unbounded:
                    // heightFactor makes the Align hug the pill vertically.
                    return Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: 1,
                      child: ConstrainedBox(
                        // Never wider than the bar it rides on.
                        constraints: BoxConstraints(
                          maxWidth: NavBarMetrics.widthFor(
                            constraints.maxWidth,
                            tabCount,
                          ),
                        ),
                        child: _ActiveWorkoutPill(
                          live: visible,
                          onTap: onTap,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted pill itself: a live dot, the program name, how far through the
/// session you are (or the rest countdown) and the elapsed time. For a stale
/// session it says so instead, and opens the screen that resolves it.
class _ActiveWorkoutPill extends ConsumerStatefulWidget {
  /// False while tucked away — the dot stops pulsing so a hidden pill never
  /// keeps the app drawing frames.
  final bool live;
  final VoidCallback onTap;

  const _ActiveWorkoutPill({required this.live, required this.onTap});

  @override
  ConsumerState<_ActiveWorkoutPill> createState() => _ActiveWorkoutPillState();
}

class _ActiveWorkoutPillState extends ConsumerState<_ActiveWorkoutPill> {
  // Kept from the last frame the session was live, so the pill still says
  // what it was while it slides away after the workout ends.
  String _title = 'Workout';
  int _elapsed = 0;
  int _doneSets = 0;
  int _totalSets = 0;

  /// When set, the pill is showing a stale session started at this time.
  DateTime? _staleSince;

  static String _titleOf(WorkoutSession session) {
    final title = session.programTitle.trim();
    return title.isEmpty ? 'Workout' : title;
  }

  void _capture(WorkoutSession session, int elapsedSeconds) {
    _title = _titleOf(session);
    _elapsed = elapsedSeconds;
    _staleSince = null;

    var done = 0;
    var total = 0;
    for (final exercise in session.completedExercises) {
      for (final set in exercise.sets) {
        total++;
        // Same rule the workout screen uses for a logged set.
        if (isSetLogged(set)) done++;
      }
    }
    _doneSets = done;
    _totalSets = total;
  }

  String get _timer {
    final s = _elapsed;
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
    final workout = ref.watch(workoutProvider);
    final session = workout.session;
    final stale = workout.staleSession;
    if (workout.isRunning && session != null) {
      _capture(session, workout.elapsedSeconds);
    } else if (stale != null) {
      _title = _titleOf(stale);
      _staleSince = stale.date;
    }
    final staleSince = _staleSince;

    return Semantics(
      button: true,
      label: staleSince != null
          ? 'Unfinished workout: $_title. Open to resume or discard'
          : 'Workout in progress: $_title, $_timer. Open workout',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Pressable(
        onTap: widget.onTap,
        haptic: HapticStrength.medium,
        scale: 0.96,
        // Chrome with a fixed slot above the bar: let text grow a little with
        // the system setting, but not enough to burst the pill.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: FloatingCapsule(
            // Soft and tight — a long floating shadow would pool on the bar
            // sitting right underneath.
            shadow: t.shadowSoft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: NavBarMetrics.accessoryHeight -
                    2 * NavBarMetrics.borderWidth,
              ),
              child: Row(
                // Hugs its content: a floating chip, not a full-width banner.
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LiveDot(
                    color: staleSince != null ? t.warning : t.primary,
                    animate: widget.live && staleSince == null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.heading(t).copyWith(fontSize: 14.5),
                        ),
                        if (staleSince != null)
                          Text(
                            'Unfinished · '
                            '${AppFormat.relativeDate(staleSince)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption(t).copyWith(
                              fontSize: 11.5,
                              color: t.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          _PillSubtitle(
                            doneSets: _doneSets,
                            totalSets: _totalSets,
                          ),
                      ],
                    ),
                  ),
                  if (staleSince == null) ...[
                    const SizedBox(width: AppSpacing.lg),
                    Text(
                      _timer,
                      style:
                          AppType.mono(t, size: 15, weight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small dot with a slow halo breathing out of it — the "this is live" cue.
class _LiveDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _LiveDot({required this.color, required this.animate});

  static const double _core = 8;
  static const double _box = 16;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.lazy * 2,
  );

  late final Animation<double> _curved =
      _pulse.drive(CurveTween(curve: AppMotion.enter));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _LiveDot old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) _syncPulse();
  }

  void _syncPulse() {
    // Honour "remove animations": a steady dot says "live" just as well.
    final pulse =
        widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (pulse) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      if (_pulse.value != 0) _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: _LiveDot._box,
        child: AnimatedBuilder(
          animation: _curved,
          builder: (context, _) {
            final v = _curved.value.clamp(0.0, 1.0);
            final halo =
                _LiveDot._core + (_LiveDot._box - _LiveDot._core) * v;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: halo,
                  height: halo,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.4 * (1 - v)),
                  ),
                ),
                Container(
                  width: _LiveDot._core,
                  height: _LiveDot._core,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The pill's second line: how many sets are logged, swapping to the live
/// rest timer while a rest is running — stepping away from the workout screen
/// should not mean losing track of it.
class _PillSubtitle extends ConsumerWidget {
  final int doneSets;
  final int totalSets;

  const _PillSubtitle({required this.doneSets, required this.totalSets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final rest = ref.watch(restTimerProvider);

    final String text;
    final Color tone;
    final Object mode;
    if (rest.isRunning) {
      text = rest.isOvertime ? 'Rested ${rest.label}' : 'Resting ${rest.label}';
      tone = rest.isOvertime ? t.success : t.primary;
      mode = rest.isOvertime ? 'rested' : 'resting';
    } else {
      text = totalSets == 0 ? 'In progress' : '$doneSets of $totalSets sets';
      tone = t.textSecondary;
      mode = 'sets';
    }

    // Keyed on the mode, not the text, so it cross-fades when a rest starts or
    // ends but not on every tick of the clock.
    return SwapTransitionBox(
      value: mode,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.caption(t).copyWith(
          fontSize: 11.5,
          color: tone,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
