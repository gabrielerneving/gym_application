import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import 'motion.dart';

enum AppButtonVariant {
  /// Filled with the primary gradient. One per screen.
  primary,

  /// Solid neutral surface — the common secondary action.
  secondary,

  /// Outlined, transparent fill.
  outline,

  /// Text only.
  ghost,

  /// Destructive, tinted with the error colour.
  danger,
}

enum AppButtonSize { small, medium, large }

/// The app's button. Handles haptics, the press dip, loading and disabled
/// states, so screens never hand-roll a `Container` + `InkWell` again.
class AppButton extends ConsumerWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;

  /// Places the icon after the label instead of before.
  final bool iconTrailing;

  /// Stretches to the parent's width.
  final bool expand;

  /// Swaps the content for a spinner and blocks taps.
  final bool loading;

  final HapticStrength haptic;

  /// Corner radius. Defaults to [AppRadius.md]; pass [AppRadius.pill] for a
  /// button that sits inside a pill (a capsule header) so the corners nest.
  final double? radius;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconTrailing = false,
    this.expand = false,
    this.loading = false,
    this.haptic = HapticStrength.medium,
    this.radius,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconTrailing = false,
    this.expand = false,
    this.loading = false,
    this.haptic = HapticStrength.light,
    this.radius,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconTrailing = false,
    this.expand = false,
    this.loading = false,
    this.haptic = HapticStrength.light,
    this.radius,
  }) : variant = AppButtonVariant.outline;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconTrailing = false,
    this.expand = false,
    this.loading = false,
    this.haptic = HapticStrength.light,
    this.radius,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconTrailing = false,
    this.expand = false,
    this.loading = false,
    this.haptic = HapticStrength.medium,
    this.radius,
  }) : variant = AppButtonVariant.danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final enabled = onPressed != null && !loading;

    final double height = switch (size) {
      AppButtonSize.small => 38,
      AppButtonSize.medium => 50,
      AppButtonSize.large => 58,
    };
    final double hPad = switch (size) {
      AppButtonSize.small => AppSpacing.lg,
      AppButtonSize.medium => AppSpacing.xl,
      AppButtonSize.large => AppSpacing.xxl,
    };
    final double fontSize = switch (size) {
      AppButtonSize.small => 14,
      AppButtonSize.medium => 15.5,
      AppButtonSize.large => 17,
    };
    final double iconSize = switch (size) {
      AppButtonSize.small => 17,
      AppButtonSize.medium => 19,
      AppButtonSize.large => 21,
    };

    final (Color fg, Color? bg, Gradient? grad, Border? border) =
        _styleFor(t, variant);

    final content = loading
        ? SizedBox(
            height: iconSize,
            width: iconSize,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null && !iconTrailing) ...[
                Icon(icon, size: iconSize, color: fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.button(t).copyWith(color: fg, fontSize: fontSize),
                ),
              ),
              if (icon != null && iconTrailing) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, size: iconSize, color: fg),
              ],
            ],
          );

    final button = AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        height: height,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          gradient: grad,
          border: border,
          borderRadius: BorderRadius.circular(radius ?? AppRadius.md),
          // Small buttons sit in toolbars and rows; a glow there spills over
          // the surrounding chrome. Only full-size CTAs get the lift.
          boxShadow: variant == AppButtonVariant.primary &&
                  enabled &&
                  size != AppButtonSize.small
              ? t.shadowPrimaryGlow
              : null,
        ),
        child: content,
      ),
    );

    return Pressable(
      onTap: enabled ? onPressed : null,
      haptic: haptic,
      scale: 0.96,
      child: button,
    );
  }

  (Color, Color?, Gradient?, Border?) _styleFor(
    AppColors t,
    AppButtonVariant v,
  ) {
    switch (v) {
      case AppButtonVariant.primary:
        return (t.onPrimary, null, t.primaryGradientDiagonal, null);
      case AppButtonVariant.secondary:
        return (t.text, t.surface, null, Border.all(color: t.outline));
      case AppButtonVariant.outline:
        return (t.text, Colors.transparent, null, Border.all(color: t.outline));
      case AppButtonVariant.ghost:
        return (t.primary, Colors.transparent, null, null);
      case AppButtonVariant.danger:
        return (
          t.error,
          t.error.withValues(alpha: t.isDark ? 0.14 : 0.09),
          null,
          Border.all(color: t.error.withValues(alpha: 0.28)),
        );
    }
  }
}

/// A circular/rounded icon-only button — the header actions of a screen.
class AppIconButton extends ConsumerWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;

  /// Draws the surface background behind the icon. Off → bare icon.
  final bool filled;

  final bool active;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 42,
    this.iconSize = 21,
    this.color,
    this.filled = true,
    this.active = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final fg = active ? t.primary : (color ?? t.text);

    final button = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: !filled
            ? Colors.transparent
            : active
                ? t.primaryWash
                : t.card,
        shape: BoxShape.circle,
        border: filled
            ? Border.all(color: active ? t.primaryWashOutline : t.outline)
            : null,
      ),
      child: Icon(icon, size: iconSize, color: fg),
    );

    final pressable = Pressable(
      onTap: onPressed,
      scale: 0.9,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: onPressed == null ? 0.4 : 1,
        child: button,
      ),
    );

    if (tooltip == null) return pressable;
    return Tooltip(message: tooltip!, child: pressable);
  }
}

/// A large floating action button used for the single most important action on
/// a screen (start workout, add exercise). Sits above the nav bar.
class AppFab extends ConsumerWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final bool extended;

  const AppFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.extended = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final showLabel = extended && label != null;

    return Pressable(
      onTap: onPressed,
      haptic: HapticStrength.medium,
      scale: 0.94,
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: showLabel ? AppSpacing.xxl : 0),
        width: showLabel ? null : 56,
        decoration: BoxDecoration(
          gradient: t.primaryGradientDiagonal,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: t.shadowPrimaryGlow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: t.onPrimary, size: 22),
            if (showLabel) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                label!,
                style: AppType.button(t).copyWith(color: t.onPrimary, fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
