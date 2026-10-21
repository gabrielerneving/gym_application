import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/design_tokens.dart';
import 'motion.dart';

/// A sliding segmented control — the app's period/mode switcher.
///
/// The selected pill animates between segments rather than snapping, which is
/// the single most recognisable piece of motion in the UI.
///
/// ```dart
/// AppSegmented<Period>(
///   value: period,
///   segments: const [
///     AppSegment(value: Period.week,  label: '7d'),
///     AppSegment(value: Period.month, label: '30d'),
///   ],
///   onChanged: (p) => setState(() => period = p),
/// )
/// ```
class AppSegmented<T> extends ConsumerWidget {
  final T value;
  final List<AppSegment<T>> segments;
  final ValueChanged<T> onChanged;
  final double height;

  const AppSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final selectedIndex = segments.indexWhere((s) => s.value == value);
    final index = selectedIndex < 0 ? 0 : selectedIndex;

    // The thumb must read as *raised* in both modes: on dark palettes that
    // means lighter than the track (a darker thumb reads as a hole), on light
    // palettes the white card on a grey track.
    final track = t.isDark ? t.card : t.surface;

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: t.outline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = segments.length;
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width - 2 * AppSpacing.screenH - 8;
          final segmentWidth = available / count;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.normal,
                curve: AppMotion.spring,
                left: index * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: t.raised,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: t.raisedRim),
                    boxShadow: t.shadowRaised,
                  ),
                ),
              ),
              Row(
                children: List.generate(count, (i) {
                  final segment = segments[i];
                  final selected = i == index;
                  return SizedBox(
                    width: segmentWidth,
                    child: Pressable(
                      haptic: HapticStrength.selection,
                      scale: 0.95,
                      onTap: () {
                        if (segment.value != value) onChanged(segment.value);
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: AppMotion.fast,
                          style: AppType.secondary(t).copyWith(
                            color: selected ? t.text : t.textSecondary,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 13.5,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (segment.icon != null) ...[
                                Icon(
                                  segment.icon,
                                  size: 15,
                                  color: selected ? t.primary : t.textSecondary,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Flexible(
                                child: Text(
                                  segment.label,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AppSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AppSegment({required this.value, required this.label, this.icon});
}

/// A standalone selectable pill. Use in horizontally scrolling filter rows
/// (exercise pickers, muscle-group filters).
class AppChip extends ConsumerWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? accent;
  final Widget? trailing;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = accent ?? t.primary;

    return Pressable(
      onTap: onTap,
      haptic: HapticStrength.selection,
      scale: 0.94,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? tone.withValues(alpha: t.isDark ? 0.18 : 0.11) : t.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? tone.withValues(alpha: 0.5) : t.outline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? tone : t.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppType.secondary(t).copyWith(
                color: selected ? tone : t.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A tiny, non-interactive label — "PR", "warm-up", "+2.5 kg".
class AppBadge extends ConsumerWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool solid;
  final double fontSize;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.solid = false,
    this.fontSize = 11.5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = color ?? t.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? tone : tone.withValues(alpha: t.isDark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: solid ? null : Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1.5, color: solid ? t.onPrimary : tone),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: solid ? t.onPrimary : tone,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Signed change indicator with an arrow: ▲ +12.4%.
/// Green for up, red for down, muted for no change — inverted when [higherIsWorse].
class DeltaBadge extends ConsumerWidget {
  final num delta;
  final String unit;

  /// Renders as a percentage instead of an absolute number.
  final bool percent;

  /// Flips the colour semantics (e.g. for "time to complete").
  final bool higherIsWorse;

  final double fontSize;
  final bool compact;

  /// Forces one colour regardless of sign (the arrow and the sign still say
  /// which way it went).
  final Color? color;

  /// Drawn on the primary gradient (a hero tile): renders in onPrimary.
  /// Semantic green/red on the gradient is ~1.5:1 — unreadable.
  final bool onGradient;

  const DeltaBadge({
    super.key,
    required this.delta,
    this.unit = '',
    this.percent = false,
    this.higherIsWorse = false,
    this.fontSize = 12,
    this.compact = false,
    this.color,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final positive = delta > 0;
    final neutral = delta == 0;
    final good = higherIsWorse ? !positive : positive;
    final tone = onGradient
        ? t.onPrimary
        : color ?? (neutral ? t.textSecondary : (good ? t.success : t.error));

    final magnitude = percent
        ? '${delta.abs().toStringAsFixed(delta.abs() < 10 ? 1 : 0)}%'
        : '${AppFormat.weight(delta.abs())}${unit.isEmpty ? '' : ' $unit'}';

    final text = neutral ? (percent ? '0%' : '—') : '${positive ? '+' : '−'}$magnitude';

    final icon = neutral
        ? Icons.remove_rounded
        : (positive ? Icons.trending_up_rounded : Icons.trending_down_rounded);

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // No change is just the dash — an icon in front read as "— —".
          if (!neutral || percent) ...[
            Icon(icon, size: fontSize + 3, color: tone),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: tone,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: onGradient ? 0.20 : (t.isDark ? 0.15 : 0.10)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // No change is just the dash — an icon in front read as "— —".
          if (!neutral || percent) ...[
            Icon(icon, size: fontSize + 3, color: tone),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: tone,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
