import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/design_tokens.dart';
import 'motion.dart';

/// Geometry of the floating nav bar. Screens use these to reserve space.
class NavBarMetrics {
  NavBarMetrics._();

  static const double height = 62;

  /// Gap between the bar and the bottom safe-area inset.
  static const double bottomGap = 20;

  /// Distance from the bottom of the screen to the top of the bar,
  /// excluding the safe-area inset.
  static const double totalHeight = height + bottomGap;
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
/// A narrow, fully detached frosted pill that hugs its content: inactive tabs
/// are icon-only, the active tab expands to reveal its label behind a filled
/// gradient pill. Swiping horizontally across the bar moves between tabs.
/// ---------------------------------------------------------------------------
class FloatingNavBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnimatedSlide(
      duration: AppMotion.normal,
      curve: AppMotion.standard,
      offset: visible ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: visible ? 1 : 0,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset + NavBarMetrics.bottomGap,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
          ),
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity;
                if (v == null) return;
                if (v > 260 && currentIndex > 0) {
                  onTap(currentIndex - 1);
                } else if (v < -260 && currentIndex < destinations.length - 1) {
                  onTap(currentIndex + 1);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: t.shadowFloating,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      height: NavBarMetrics.height,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: t.glass,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: t.isDark
                              ? Colors.white.withValues(alpha: 0.09)
                              : Colors.white.withValues(alpha: 0.7),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(destinations.length, (i) {
                          return _NavItem(
                            destination: destinations[i],
                            selected: i == currentIndex,
                            onTap: () => onTap(i),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
      duration: AppMotion.normal,
      curve: AppMotion.spring,
      builder: (context, raw, _) {
        // The spring curve overshoots past 1 — clamp before it reaches any
        // opacity or colour interpolation.
        final v = raw.clamp(0.0, 1.0);

        return Pressable(
          onTap: onTap,
          haptic: HapticStrength.selection,
          scale: 0.9,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: EdgeInsets.symmetric(horizontal: 14 + 3 * v),
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              gradient: v == 0
                  ? null
                  : LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        t.primary.withValues(alpha: v),
                        t.primaryLight.withValues(alpha: v),
                      ],
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? destination.activeIcon : destination.icon,
                  size: 22 + 1.5 * v,
                  color: Color.lerp(t.textSecondary, t.onPrimary, v),
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: v,
                    child: Opacity(
                      opacity: v,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: t.onPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
