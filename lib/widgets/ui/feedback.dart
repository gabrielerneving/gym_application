import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/design_tokens.dart';
import 'app_buttons.dart';
import 'floating_nav_bar.dart';
import 'motion.dart';

/// The "nothing here yet" state. Always give the user a way forward — an empty
/// screen with no action is a dead end.
class EmptyState extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Icon on the action button. Defaults to "+", which is wrong for actions
  /// like "Go back" or "Delete workout" — pass one that matches the label.
  final IconData actionIcon;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
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
              BalancedText(
                title,
                textAlign: TextAlign.center,
                style: AppType.title(t),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                BalancedText(
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
                  icon: actionIcon,
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
    // Room inside the padding and the 1px rim. The placeholder lines adapt
    // to it, so a short row-shaped skeleton never overflows.
    final inner = height - AppSpacing.lg * 2 - 2;
    final List<Widget> lines;
    if (inner >= 56) {
      lines = const [
        SkeletonBox(width: 80, height: 12),
        SkeletonBox(width: 110, height: 26),
        SkeletonBox(width: 60, height: 12),
      ];
    } else if (inner >= 30) {
      lines = const [
        SkeletonBox(width: 120, height: 14),
        SkeletonBox(width: 76, height: 10),
      ];
    } else {
      lines = const [SkeletonBox(width: 120, height: 12)];
    }

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
        mainAxisAlignment: lines.length == 1
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: lines,
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
            BalancedText(
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
          // Clears the live-workout pill as well when it is floating above
          // the nav bar, instead of landing on top of it.
          margin: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.navBarClearance +
                (ref.read(hasWorkoutAccessoryProvider)
                    ? NavBarMetrics.accessoryClearance
                    : 0),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: t.outline),
          ),
        ),
      );
  }
}

/// Text that wraps into evenly filled lines instead of leaving one orphan word
/// on the last line — CSS `text-wrap: balance` for short, centred copy
/// (dialog titles and messages, empty states).
///
/// It keeps exactly the line count a plain [Text] would use at the available
/// width and only picks the narrowest width that still fits in that many
/// lines, then aligns that block per [textAlign]. Single-line text is
/// untouched. Safe inside intrinsic-sizing parents (it is a render object, not
/// a `LayoutBuilder`). Not for long paragraphs — use [Text].
class BalancedText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;

  const BalancedText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = switch (textAlign) {
      TextAlign.center || TextAlign.justify => Alignment.topCenter,
      TextAlign.right || TextAlign.end => Alignment.topRight,
      _ => Alignment.topLeft,
    };
    return _Balance(
      alignment: alignment,
      child: Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }
}

class _Balance extends SingleChildRenderObjectWidget {
  final Alignment alignment;

  const _Balance({required this.alignment, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBalance(alignment);

  @override
  void updateRenderObject(BuildContext context, _RenderBalance renderObject) {
    renderObject.alignment = alignment;
  }
}

class _RenderBalance extends RenderShiftedBox {
  _RenderBalance(this._alignment) : super(null);

  Alignment _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  /// The narrowest width ≤ `inner.maxWidth` that wraps the child into the
  /// same number of lines (same height) as the full width does.
  double _balancedWidth(RenderBox child, BoxConstraints inner) {
    final maxWidth = inner.maxWidth;
    if (!maxWidth.isFinite) return maxWidth;
    final wrapped = child.getDryLayout(inner).height;
    final oneLine = child.getDryLayout(const BoxConstraints()).height;
    if (wrapped <= oneLine + 0.5) return maxWidth;

    var lo = 0.0;
    var hi = maxWidth;
    for (var i = 0; i < 12 && hi - lo > 1; i++) {
      final mid = (lo + hi) / 2;
      final height = child.getDryLayout(BoxConstraints(maxWidth: mid)).height;
      if (height > wrapped + 0.5) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hi.ceilToDouble().clamp(0.0, maxWidth);
  }

  Size _sizeFor(BoxConstraints constraints, Size childSize) =>
      constraints.constrain(Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : childSize.width,
        childSize.height,
      ));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final inner = constraints.loosen();
    final width = _balancedWidth(child, inner);
    return _sizeFor(
      constraints,
      child.getDryLayout(inner.copyWith(maxWidth: width)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final inner = constraints.loosen();
    final width = _balancedWidth(child, inner);
    child.layout(inner.copyWith(maxWidth: width), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
    (child.parentData! as BoxParentData).offset =
        _alignment.alongOffset(size - child.size as Offset);
  }
}
