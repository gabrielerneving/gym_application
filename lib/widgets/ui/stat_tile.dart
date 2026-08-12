import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/design_tokens.dart';
import 'app_card.dart';
import 'app_chips.dart';
import 'motion.dart';

/// A single headline number with a label — the atom of every stats screen.
///
/// ```dart
/// StatTile(
///   label: 'This month',
///   value: 14,
///   unit: 'workouts',
///   icon: Icons.calendar_today_rounded,
///   delta: 3,
/// )
/// ```
class StatTile extends ConsumerWidget {
  final String label;

  /// Animated from zero on first paint.
  final double value;

  /// Decimal places for [value].
  final int decimals;

  /// Overrides the rendered number entirely (for pre-formatted strings).
  final String? valueText;

  final String? unit;
  final IconData? icon;

  /// Change vs the previous period. Renders a [DeltaBadge] when non-null.
  final num? delta;
  final bool deltaIsPercent;
  final bool deltaHigherIsWorse;

  /// Paints the tile with the primary gradient. One per grid, at most.
  final bool highlight;

  final VoidCallback? onTap;

  /// A tiny trend line drawn at the bottom of the tile.
  final List<double>? sparkline;

  final Color? accent;

  const StatTile({
    super.key,
    required this.label,
    this.value = 0,
    this.decimals = 0,
    this.valueText,
    this.unit,
    this.icon,
    this.delta,
    this.deltaIsPercent = false,
    this.deltaHigherIsWorse = false,
    this.highlight = false,
    this.onTap,
    this.sparkline,
    this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = highlight ? t.onPrimary : (accent ?? t.primary);
    final textColor = highlight ? t.onPrimary : t.text;
    final subColor =
        highlight ? t.onPrimary.withValues(alpha: 0.78) : t.textSecondary;

    return AppCard(
      onTap: onTap,
      gradient: highlight,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: tone),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.secondary(t).copyWith(
                    color: subColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: valueText != null
                    ? Text(
                        valueText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.metric(t, size: 28)
                            .copyWith(color: textColor),
                      )
                    : CountUp(
                        value: value,
                        decimals: decimals,
                        style: AppType.metric(t, size: 28)
                            .copyWith(color: textColor),
                      ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: AppType.caption(t).copyWith(color: subColor),
                ),
              ],
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: AppSpacing.sm),
            DeltaBadge(
              delta: delta!,
              percent: deltaIsPercent,
              higherIsWorse: deltaHigherIsWorse,
              compact: true,
              fontSize: 11.5,
            ),
          ],
          if (sparkline != null && sparkline!.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 22,
              child: Sparkline(
                values: sparkline!,
                color: highlight ? t.onPrimary : (accent ?? t.primary),
                fill: !highlight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays [StatTile]s out in a responsive grid with the app's spacing.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double aspectRatio;

  const StatGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.aspectRatio = 1.32,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: aspectRatio,
      children: [
        for (var i = 0; i < children.length; i++)
          FadeSlideIn(index: i, child: children[i]),
      ],
    );
  }
}

/// A compact label/value pair for use inside cards and detail rows.
class MetricRow extends ConsumerWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final Widget? trailing;

  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: t.textTertiary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(label, style: AppType.secondary(t))),
          Text(
            value,
            style: AppType.mono(t).copyWith(color: valueColor ?? t.text),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A labelled horizontal bar — "Chest ▇▇▇▇▇░░ 18 sets".
/// The workhorse of the muscle-group and popular-workout breakdowns.
class StatBar extends ConsumerWidget {
  final String label;
  final double value;
  final double max;
  final String? valueLabel;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Optional target band drawn behind the bar (e.g. 10–20 sets/week).
  final double? targetMin;
  final double? targetMax;

  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.valueLabel,
    this.color,
    this.icon,
    this.onTap,
    this.targetMin,
    this.targetMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = color ?? t.primary;
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);

    final bar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: tone),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(t).copyWith(fontSize: 14),
              ),
            ),
            Text(
              valueLabel ?? AppFormat.weight(value),
              style: AppType.mono(t, size: 14).copyWith(color: tone),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  if (targetMin != null && targetMax != null && max > 0)
                    Positioned(
                      left: width * (targetMin! / max).clamp(0.0, 1.0),
                      width: width *
                          ((targetMax! - targetMin!) / max).clamp(0.0, 1.0),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.textSecondary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: fraction),
                    duration: AppMotion.lazy,
                    curve: AppMotion.enter,
                    builder: (context, f, _) => Container(
                      width: width * f,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tone.withValues(alpha: 0.75), tone],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: bar,
    );

    if (onTap == null) return padded;
    return Pressable(scale: 0.99, onTap: onTap, child: padded);
  }
}

/// A minimal trend line. No axes, no labels — just the shape of the data.
/// Used inside stat tiles and list rows where a full chart would be noise.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final bool fill;
  final double strokeWidth;

  /// Draws a dot on the final point.
  final bool showLast;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.fill = true,
    this.strokeWidth = 2,
    this.showLast = true,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.lazy,
      curve: AppMotion.enter,
      builder: (context, progress, _) => CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          fill: fill,
          strokeWidth: strokeWidth,
          progress: progress,
          showLast: showLast,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool fill;
  final double strokeWidth;
  final double progress;
  final bool showLast;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.fill,
    required this.strokeWidth,
    required this.progress,
    required this.showLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;

    final dx = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * dx,
          size.height - ((values[i] - minV) / range) * (size.height - strokeWidth) -
              strokeWidth / 2,
        ),
    ];

    // Reveal left-to-right.
    final visibleCount = (points.length * progress).ceil().clamp(2, points.length);
    final visible = points.sublist(0, visibleCount);

    final path = Path()..moveTo(visible.first.dx, visible.first.dy);
    for (var i = 1; i < visible.length; i++) {
      final prev = visible[i - 1];
      final curr = visible[i];
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(visible.last.dx, size.height)
        ..lineTo(visible.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showLast && progress > 0.98) {
      canvas.drawCircle(
        visible.last,
        strokeWidth + 1,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values ||
      old.color != color ||
      old.progress != progress ||
      old.fill != fill;
}
