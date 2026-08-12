import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/design_tokens.dart';

/// An animated circular progress ring with a value in the middle.
///
/// Used for goal completion, consistency scores and muscle-group coverage.
class ProgressRing extends ConsumerWidget {
  /// 0.0 – 1.0. Values above 1 are drawn as a full ring plus an overflow arc.
  final double progress;

  final double size;
  final double strokeWidth;
  final Color? color;

  /// Rendered in the centre of the ring.
  final Widget? child;

  /// Convenience: renders "62%" style text when [child] is null.
  final String? label;
  final String? sublabel;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 10,
    this.color,
    this.child,
    this.label,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = color ?? t.primary;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: AppMotion.lazy,
        curve: AppMotion.enter,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: value,
              trackColor: t.surface,
              colors: [tone, t.primaryLight],
              overflowColor: t.success,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: child ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (label != null)
                        Text(
                          label!,
                          style: AppType.metric(t, size: size * 0.22),
                        ),
                      if (sublabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sublabel!,
                          style: AppType.caption(t)
                              .copyWith(fontSize: size * 0.09),
                        ),
                      ],
                    ],
                  ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final List<Color> colors;
  final Color overflowColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.colors,
    required this.overflowColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final main = progress.clamp(0.0, 1.0);
    if (main > 0) {
      canvas.drawArc(
        rect,
        start,
        2 * math.pi * main,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            colors: colors,
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Anything beyond 100% is drawn as a second, thinner arc on top.
    if (progress > 1.0) {
      final overflow = (progress - 1.0).clamp(0.0, 1.0);
      canvas.drawArc(
        rect,
        start,
        2 * math.pi * overflow,
        false,
        Paint()
          ..color = overflowColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// A row of small rings/dots representing the last N days of training —
/// a compact weekly consistency strip.
class WeekStrip extends ConsumerWidget {
  /// Most recent day last. `true` = trained that day.
  final List<bool> days;

  /// Labels under each dot (e.g. M T W T F S S).
  final List<String>? labels;

  final double dotSize;

  const WeekStrip({
    super.key,
    required this.days,
    this.labels,
    this.dotSize = 34,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < days.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: AppMotion.normal,
                curve: AppMotion.spring,
                builder: (context, v, child) => Transform.scale(
                  scale: 0.6 + 0.4 * v.clamp(0.0, 1.2),
                  child: child,
                ),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: days[i] ? null : t.surface,
                    gradient: days[i] ? t.primaryGradientDiagonal : null,
                    shape: BoxShape.circle,
                    border: days[i] ? null : Border.all(color: t.outline),
                  ),
                  child: days[i]
                      ? Icon(Icons.check_rounded,
                          size: dotSize * 0.5, color: t.onPrimary)
                      : null,
                ),
              ),
              if (labels != null && i < labels!.length) ...[
                const SizedBox(height: 6),
                Text(
                  labels![i],
                  style: AppType.caption(t).copyWith(fontSize: 10.5),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
