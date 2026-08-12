import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/design_tokens.dart';
import 'app_buttons.dart';
import 'motion.dart';

/// The "nothing here yet" state. Always give the user a way forward — an empty
/// screen with no action is a dead end.
class EmptyState extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(AppSpacing.xxxl),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Center(
      child: Padding(
        padding: padding,
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      t.primary.withValues(alpha: t.isDark ? 0.22 : 0.14),
                      t.primary.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Icon(icon, size: 34, color: t.primary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppType.title(t),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppType.secondary(t).copyWith(fontSize: 14.5),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  icon: Icons.add_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A grey block that shimmers while data loads. Compose a few of these into the
/// shape of the real content — it reads far better than a lone spinner.
class SkeletonBox extends ConsumerWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return ShimmerBox(
      baseColor: t.surface,
      highlightColor: t.isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.85),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A skeleton shaped like a stat card.
class SkeletonCard extends ConsumerWidget {
  final double height;

  const SkeletonCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          SkeletonBox(width: 80, height: 12),
          SkeletonBox(width: 110, height: 26),
          SkeletonBox(width: 60, height: 12),
        ],
      ),
    );
  }
}

/// Full-screen loading state — a centred spinner with an optional caption.
class LoadingState extends ConsumerWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(color: t.primary, strokeWidth: 2.6),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: AppType.secondary(t)),
          ],
        ],
      ),
    );
  }
}

/// An inline error block with a retry affordance.
class ErrorState extends ConsumerWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 36, color: t.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.secondary(t).copyWith(fontSize: 14.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton.outline(
                label: 'Try again',
                onPressed: onRetry,
                icon: Icons.refresh_rounded,
                size: AppButtonSize.small,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Themed snack bars. Use instead of building `SnackBar` by hand so feedback
/// looks the same everywhere.
class AppSnack {
  AppSnack._();

  static void show(
    BuildContext context,
    WidgetRef ref,
    String message, {
    IconData? icon,
    bool isError = false,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    final t = ref.read(themeProvider);
    final tone = isError ? t.error : t.primary;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                icon ?? (isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded),
                color: tone,
                size: 19,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message, style: AppType.body(t))),
            ],
          ),
          backgroundColor: t.elevated,
          duration: duration,
          action: action,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.navBarClearance,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: t.outline),
          ),
        ),
      );
  }
}
