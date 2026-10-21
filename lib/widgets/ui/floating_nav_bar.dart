import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import 'motion.dart';

/// Geometry of the floating nav bar. Screens use these to reserve space.
class NavBarMetrics {
  NavBarMetrics._();

  static const double height = 60;

  /// Gap between the bar and the bottom safe-area inset. Deliberately small —
  /// the bar should read as resting *on* the bottom edge, not hovering in the
  /// middle of the empty strip above it.
  static const double bottomGap = 8;

  /// Distance from the bottom of the screen to the top of the bar,
  /// excluding the safe-area inset.
  static const double totalHeight = height + bottomGap;

  /// Inset between the bar's edge and the tab slots. Also the gutter the
  /// travelling bubble leaves around itself.
  static const double innerPadding = 5;

  /// The hairline rim. `Container` adds a decoration's border as padding, so
  /// the bar has to budget for it or the tab row overflows by 2px.
  static const double borderWidth = 1;

  /// Total horizontal chrome around the tab slots.
  static const double horizontalChrome = (innerPadding + borderWidth) * 2;

  /// Width bounds for a single tab slot. The bar hugs `slot * tabCount` so it
  /// stays centred and never stretches to a full-width banner on a tablet.
  static const double minSlotWidth = 60;
  static const double maxSlotWidth = 78;

  /// Backdrop blur of the frosted capsule.
  static const double blurSigma = 18;

  /// Height of the bar's accessory — the live-workout pill that floats just
  /// above it while a session is running.
  static const double accessoryHeight = 48;

  /// Air between the accessory and the bar. The same as the bar leaves below
  /// itself, so inset → bar → pill keeps one rhythm.
  static const double accessoryGap = bottomGap;

  /// Extra bottom clearance content needs while the accessory is showing.
  static const double accessoryClearance = accessoryHeight + accessoryGap;

  /// Width of one tab slot when [count] tabs share [available] width.
  static double slotWidthFor(double available, int count) =>
      ((available - horizontalChrome) / count)
          .clamp(minSlotWidth, maxSlotWidth);

  /// Width of the whole bar for [count] tabs. Anything that floats with the
  /// bar uses this as its ceiling so it never reads wider than the bar.
  static double widthFor(double available, int count) => math.min(
        slotWidthFor(available, count) * count + horizontalChrome,
        available,
      );
}

/// The frosted capsule the nav bar is made of.
///
/// Anything that floats *with* the bar — the live-workout pill — is cut from
/// the same material, so the two read as one family instead of two unrelated
/// overlays.
class FloatingCapsule extends ConsumerWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  /// Defaults to [AppColors.shadowFloating].
  final List<BoxShadow>? shadow;

  const FloatingCapsule({
    super.key,
    required this.child,
    this.height,
    this.padding,
    this.shadow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final radius = BorderRadius.circular(AppRadius.pill);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow ?? t.shadowFloating,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: NavBarMetrics.blurSigma,
            sigmaY: NavBarMetrics.blurSigma,
          ),
          child: Container(
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              // Dark: translucent enough to read as sitting over the page,
              // opaque enough that the labels never fight the content behind.
              // Light: white-on-near-white has no contrast of its own, so the
              // capsule is nearly opaque and carries a real rim — together
              // with the stronger light-palette floating shadow that is what
              // lifts it off the page.
              color: t.elevated.withValues(alpha: t.isDark ? 0.62 : 0.92),
              border: Border.all(
                color: t.isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : t.text.withValues(alpha: 0.12),
                width: NavBarMetrics.borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A single destination in the [FloatingNavBar].
class NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// ---------------------------------------------------------------------------
/// The floating navigation bar.
///
/// A compact, detached capsule sitting just above the system inset. Translucent
/// with a soft blur behind it so content shows through, and nothing more — no
/// highlights, no sheens.
///
/// Selection is a single travelling bubble rather than four independent pills.
/// It is driven by one spring simulation over a continuous tab position, so it
/// overshoots, stretches in the direction of travel and settles — and every
/// icon it passes over lights up partially on the way. Swiping horizontally
/// across the bar moves between tabs.
/// ---------------------------------------------------------------------------
class FloatingNavBar extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavDestination> destinations;

  /// Slides the bar out of view (used while a full-screen flow is open).
  final bool visible;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
    this.visible = true,
  });

  @override
  ConsumerState<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends ConsumerState<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  /// The Material 3 Expressive "spatial" spring: leaves fast, overshoots once,
  /// settles soft. Under-damped on purpose — a critically damped bubble reads
  /// as a cross-fade rather than as something with mass.
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 440,
    ratio: 0.72,
  );

  /// Unbounded: the spring is allowed to carry `value` past 1 and back.
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: 1);

  late double _from = widget.currentIndex.toDouble();
  late double _to = widget.currentIndex.toDouble();

  /// Continuous tab position, in slots.
  double get _position => _from + (_to - _from) * _controller.value;

  /// Travel speed, in slots per second.
  double get _speed => (_to - _from) * _controller.velocity;

  @override
  void didUpdateWidget(covariant FloatingNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _springTo(widget.currentIndex.toDouble());
    }
  }

  /// Retargets mid-flight without losing momentum: the bubble's current
  /// position and velocity become the new simulation's starting conditions.
  void _springTo(double target) {
    final start = _position;
    final span = target - start;
    if (span.abs() < 0.001) {
      _controller.stop();
      _from = _to = target;
      _controller.value = 1;
      return;
    }
    // Convert slots/sec into the new simulation's 0→1 units.
    final normalisedVelocity = _speed / span;
    _from = start;
    _to = target;
    _controller.animateWith(
      SpringSimulation(_spring, 0, 1, normalisedVelocity),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSwipe(DragEndDetails details) {
    final v = details.primaryVelocity;
    if (v == null) return;
    if (v > 260 && widget.currentIndex > 0) {
      HapticFeedback.selectionClick();
      widget.onTap(widget.currentIndex - 1);
    } else if (v < -260 &&
        widget.currentIndex < widget.destinations.length - 1) {
      HapticFeedback.selectionClick();
      widget.onTap(widget.currentIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // A bar floating above the keyboard is worse than no bar at all.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final show = widget.visible && !keyboardOpen;

    return AnimatedSlide(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      offset: show ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: show ? 1 : 0,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset + NavBarMetrics.bottomGap,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = widget.destinations.length;
              final slot =
                  NavBarMetrics.slotWidthFor(constraints.maxWidth, count);
              final barWidth =
                  NavBarMetrics.widthFor(constraints.maxWidth, count);

              // A Row, never a Center. The bottom Align hands down *loose*
              // constraints, and a Center with a bounded-but-loose height
              // expands to the full stack instead of shrink-wrapping — which
              // parks the bar in the vertical middle of the screen and leaves
              // the enclosing Align with nothing left to push down. A Row
              // centres horizontally and still hugs the bar's own height.
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: barWidth,
                    child: _capsule(t, slot),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _capsule(AppColors t, double slot) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: _handleSwipe,
      child: FloatingCapsule(
        height: NavBarMetrics.height,
        padding: const EdgeInsets.all(NavBarMetrics.innerPadding),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final position = _position;
            return Stack(
              children: [
                _bubble(t, slot, position),
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < widget.destinations.length; i++)
                        SizedBox(
                          width: slot,
                          child: _NavItem(
                            theme: t,
                            destination: widget.destinations[i],
                            // Falls off linearly with distance, so an icon
                            // the bubble passes over lights up partially on
                            // the way through.
                            selection: 1 - (position - i).abs(),
                            onTap: () => widget.onTap(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The travelling selection bubble.
  Widget _bubble(AppColors t, double slot, double position) {
    // Stretch along the direction of travel and squash across it, scaled by
    // how fast the bubble is actually moving. This is what makes it read as a
    // drop of liquid instead of a rectangle sliding on rails.
    final stretch = (_speed.abs() * 0.045).clamp(0.0, 0.20);
    const gutter = 2.0;

    return Positioned(
      left: position * slot + gutter,
      top: 0,
      bottom: 0,
      width: slot - gutter * 2,
      child: IgnorePointer(
        child: Transform.scale(
          scaleX: 1 + stretch,
          scaleY: 1 - stretch * 0.5,
          // A quiet primary wash, not the gradient: the screen's own CTA is
          // the one hero element, and the bar should never compete with it.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: t.primary.withValues(alpha: t.isDark ? 0.17 : 0.11),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppColors theme;
  final NavDestination destination;

  /// How selected this tab is, 0→1. Read straight off the bubble's position,
  /// so it is continuous rather than a boolean.
  final double selection;

  final VoidCallback onTap;

  const _NavItem({
    required this.theme,
    required this.destination,
    required this.selection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = selection.clamp(0.0, 1.0);
    final tint = Color.lerp(theme.textSecondary, theme.primary, v)!;

    return Pressable(
      onTap: onTap,
      haptic: HapticStrength.selection,
      scale: 0.9,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 23,
            // Cross-fading a glyph with itself only dims it mid-transition, so
            // tabs whose two icons are the same render once.
            child: destination.icon == destination.activeIcon
                ? Center(
                    child: Icon(
                      destination.icon,
                      size: 21 + 1.3 * v,
                      color: tint,
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - v,
                        child: Icon(destination.icon, size: 21, color: tint),
                      ),
                      Opacity(
                        opacity: v,
                        child: Icon(
                          destination.activeIcon,
                          size: 21 + 1.3 * v,
                          color: tint,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            destination.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: tint,
              fontSize: 10.5,
              height: 1.0,
              fontWeight: FontWeight.lerp(
                FontWeight.w600,
                FontWeight.w800,
                v,
              ),
              letterSpacing: -0.05,
            ),
          ),
        ],
      ),
    );
  }
}
