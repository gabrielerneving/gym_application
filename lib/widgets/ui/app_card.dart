import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import 'motion.dart';

/// The default surface. Everything that groups content sits in one of these.
///
/// ```dart
/// AppCard(
///   onTap: () => ...,
///   child: Column(children: [...]),
/// )
/// ```
class AppCard extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  /// Paints the primary gradient instead of the flat card colour. Reserve this
  /// for one hero element per screen.
  final bool gradient;

  /// Uses the [AppColors.surface] tone — for cards nested inside other cards.
  final bool inset;

  /// Custom background, overrides [gradient]/[inset].
  final Color? color;

  final Border? border;
  final List<BoxShadow>? shadow;
  final bool showBorder;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.radius = AppRadius.card,
    this.gradient = false,
    this.inset = false,
    this.color,
    this.border,
    this.shadow,
    this.showBorder = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final background = color ?? (inset ? t.surface : t.card);

    final decorated = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: gradient ? null : background,
        gradient: gradient ? t.primaryGradientDiagonal : null,
        borderRadius: BorderRadius.circular(radius),
        border: border ??
            (showBorder && !gradient
                ? Border.all(color: t.outline, width: 1)
                : null),
        boxShadow: shadow ??
            (gradient
                ? t.shadowPrimaryGlow
                : (inset ? null : t.shadowSoft)),
      ),
      child: child,
    );

    final withMargin =
        margin == null ? decorated : Padding(padding: margin!, child: decorated);

    if (onTap == null && onLongPress == null) return withMargin;

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.985,
      borderRadius: BorderRadius.circular(radius),
      child: withMargin,
    );
  }
}

/// A frosted-glass surface. Only use where content scrolls *underneath* the
/// element — the nav bar, sticky headers, the active-workout banner. Blur is
/// expensive; a plain [AppCard] is the right default everywhere else.
class GlassSurface extends ConsumerWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final List<BoxShadow>? shadow;
  final Color? tint;

  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.xl,
    this.blur = 24,
    this.padding,
    this.border,
    this.shadow,
    this.tint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? t.shadowFloating,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? t.glass,
              borderRadius: BorderRadius.circular(radius),
              border: border ??
                  Border.all(
                    color: t.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.65),
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A rounded square holding an icon — the visual anchor of a list row.
class IconBadge extends ConsumerWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  /// Filled with the primary gradient. Off → soft tinted wash.
  final bool filled;

  /// Overrides the tint colour (defaults to the theme primary).
  final Color? color;

  final double radius;

  const IconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 21,
    this.filled = false,
    this.color,
    this.radius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = color ?? t.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? tone : tone.withValues(alpha: t.isDark ? 0.16 : 0.11),
        gradient: filled && color == null ? t.primaryGradientDiagonal : null,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: filled ? AppColors.contrastOn(tone) : tone,
      ),
    );
  }
}

/// A tappable navigation row: icon, title, optional subtitle, chevron.
/// This is the building block for the Statistics hub and Settings.
class AppTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the chevron (e.g. with a Switch or a value label).
  final Widget? trailing;

  final Color? iconColor;
  final bool filledIcon;
  final bool showChevron;
  final EdgeInsetsGeometry? padding;

  /// Renders without the card background — for rows stacked inside a card.
  final bool bare;

  const AppTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.filledIcon = false,
    this.showChevron = true,
    this.padding,
    this.bare = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final row = Row(
      children: [
        IconBadge(icon: icon, color: iconColor, filled: filledIcon),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppType.heading(t)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: AppType.secondary(t),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (showChevron && onTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right_rounded, color: t.textTertiary, size: 22),
        ],
      ],
    );

    if (bare) {
      final content = Padding(
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
        child: row,
      );
      if (onTap == null) return content;
      return Pressable(scale: 0.99, onTap: onTap, child: content);
    }

    return AppCard(
      onTap: onTap,
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
      child: row,
    );
  }
}

/// Groups several [AppTile]s with `bare: true` into one card with hairlines
/// between the rows — the iOS/One UI settings-group pattern.
class AppTileGroup extends ConsumerWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const AppTileGroup({super.key, required this.children, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 76, right: AppSpacing.lg),
            child: Divider(height: 1, thickness: 1, color: t.divider),
          ),
        );
      }
    }

    return AppCard(
      padding: padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}
