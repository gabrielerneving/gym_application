import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'ui/ui.dart';

/// The muscle-distribution radar.
///
/// One filled polygon showing how the user's working sets are spread across the
/// muscle groups. The axis is *relative* — the outer ring is whichever group was
/// trained most — so the shape answers "am I lopsided?" at a glance. Numeric
/// ticks are deliberately hidden: a percentage of an unlabelled maximum is
/// noise, and the per-group numbers live on the axis titles instead.
///
/// Restyled for the design system: every colour comes from the theme, so it
/// reads on the light palettes as well as the dark ones.
class MuscleRadarChartWidget extends ConsumerWidget {
  /// Working sets per muscle group. Missing groups count as zero.
  final Map<String, int> muscleGroupCounts;

  /// Axis order, clockwise from the top. Defaults to a push/pull/legs walk
  /// around the body so neighbouring axes are related muscles.
  final List<String>? groups;

  const MuscleRadarChartWidget({
    super.key,
    required this.muscleGroupCounts,
    this.groups,
  });

  /// Kept identical to the previous implementation so the chart keeps the same
  /// familiar shape between releases.
  static const List<String> defaultOrder = [
    'Chest',
    'Shoulders',
    'Back',
    'Biceps',
    'Triceps',
    'Quads',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Abs',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    // 'Other' is not a body part — it never gets an axis.
    final order = (groups ?? defaultOrder).where((g) => g != 'Other').toList();
    final values = [for (final g in order) muscleGroupCounts[g] ?? 0];
    final total = values.fold<int>(0, (sum, v) => sum + v);

    // A radar needs at least a triangle, and something to draw.
    if (order.length < 3 || total == 0) {
      return const _ChartEmpty(
        icon: Icons.radar_rounded,
        message: 'No sets to plot in this window',
      );
    }

    final maxValue = values.reduce(math.max).toDouble();

    return TweenAnimationBuilder<double>(
      // Restarts the entrance whenever the underlying numbers change.
      key: ValueKey('radar-${values.join('-')}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (context, v, child) {
        final p = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.scale(scale: 0.9 + 0.1 * p, child: child),
        );
      },
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              fillColor: t.primary.withValues(alpha: t.isDark ? 0.22 : 0.16),
              borderColor: t.primary,
              borderWidth: 2.5,
              entryRadius: 3,
              dataEntries: [
                for (final value in values)
                  RadarEntry(value: (value / maxValue) * 100),
              ],
            ),
          ],
          radarBackgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          radarBorderData: BorderSide(color: t.outline, width: 1),
          titlePositionPercentageOffset: 0.14,
          titleTextStyle: AppType.caption(t).copyWith(
            color: t.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          getTitle: (index, angle) {
            if (index < 0 || index >= order.length) {
              return const RadarChartTitle(text: '', angle: 0);
            }
            // Angle stays flat: rotated labels around a 10-axis radar are
            // noticeably harder to read than horizontal ones.
            return RadarChartTitle(
              text: '${order[index]}\n${values[index]}',
              angle: 0,
            );
          },
          tickCount: 4,
          // The rings are a relative scale, so their numbers would mislead.
          ticksTextStyle: const TextStyle(
            color: Colors.transparent,
            fontSize: 8,
          ),
          tickBorderData: BorderSide(color: t.outline, width: 1),
          gridBorderData: BorderSide(color: t.outline, width: 1),
          radarTouchData: RadarTouchData(
            enabled: true,
            touchCallback: (FlTouchEvent event, RadarTouchResponse? response) {
              // Only on the initial press — not while dragging across axes.
              if (event is FlTapDownEvent && response?.touchedSpot != null) {
                HapticStrength.selection.fire();
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Shown instead of a chart when there is nothing to draw.
class _ChartEmpty extends ConsumerWidget {
  final IconData icon;
  final String message;

  const _ChartEmpty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: t.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.secondary(t),
          ),
        ],
      ),
    );
  }
}
