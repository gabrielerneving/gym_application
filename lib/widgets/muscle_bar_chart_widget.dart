import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'ui/ui.dart';

/// Working sets per muscle group as vertical bars, biggest first.
///
/// The companion to the radar: the radar shows the *shape* of the distribution,
/// this shows the actual numbers. Categorical fills come from the theme's data
/// palette so the bars stay distinguishable on every palette, light or dark.
class MuscleBarChartWidget extends ConsumerWidget {
  /// Working sets per muscle group. Zero-set groups are dropped — an empty
  /// column carries no information and just eats horizontal room.
  final Map<String, int> muscleGroupCounts;

  /// Upper bound on how many bars are drawn, so the labels stay legible.
  final int maxBars;

  const MuscleBarChartWidget({
    super.key,
    required this.muscleGroupCounts,
    this.maxBars = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    final entries = muscleGroupCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const _ChartEmpty(
        icon: Icons.bar_chart_rounded,
        message: 'No sets to plot in this window',
      );
    }

    final shown = entries.take(maxBars).toList();
    final maxValue = shown.first.value.toDouble();
    final step = _step(maxValue);
    // One full step of headroom above the tallest bar, and a round maxY so the
    // grid lines land on whole numbers.
    final maxY = step * ((maxValue / step).floor() + 1);
    final barWidth = shown.length > 7 ? 13.0 : 20.0;

    return TweenAnimationBuilder<double>(
      // Replays the grow-up whenever the numbers behind it change.
      key: ValueKey('bars-${shown.map((e) => '${e.key}${e.value}').join()}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.lazy,
      curve: AppMotion.enter,
      builder: (context, progress, _) {
        final p = progress.clamp(0.0, 1.0);

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            minY: 0,
            barGroups: [
              for (var i = 0; i < shown.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: shown[i].value.toDouble() * p,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          t.dataColor(i).withValues(alpha: 0.55),
                          t.dataColor(i),
                        ],
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: t.surface,
                      ),
                    ),
                  ],
                ),
            ],
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (value) => FlLine(
                color: t.outline,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= shown.length) return const SizedBox.shrink();
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      child: Text(
                        _shortName(shown[i].key),
                        style: AppType.caption(t).copyWith(
                          color: t.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: step,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6,
                    child: Text(
                      value.toInt().toString(),
                      style: AppType.caption(t).copyWith(
                        color: t.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: true,
              touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
                // Only on the initial press — not while dragging across bars.
                if (event is FlTapDownEvent && response?.spot != null) {
                  HapticStrength.selection.fire();
                }
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => t.elevated,
                tooltipRoundedRadius: AppRadius.sm,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final i = group.x.toInt();
                  if (i < 0 || i >= shown.length) return null;
                  final entry = shown[i];
                  return BarTooltipItem(
                    '${entry.key}\n${entry.value} ${entry.value == 1 ? 'set' : 'sets'}',
                    AppType.mono(t, size: 12).copyWith(color: t.text),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// A round-ish grid step so the axis reads 0/5/10/15 rather than 0/7/14/21.
  static double _step(double maxValue) {
    final raw = maxValue / 4;
    if (raw <= 1) return 1;
    if (raw <= 2) return 2;
    if (raw <= 5) return 5;
    if (raw <= 10) return 10;
    if (raw <= 25) return 25;
    return (raw / 50).ceilToDouble() * 50;
  }

  /// Axis labels have ~34px each — full names do not fit.
  static String _shortName(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest':
        return 'CHST';
      case 'Back':
        return 'BACK';
      case 'Shoulders':
        return 'SHLD';
      case 'Biceps':
        return 'BIC';
      case 'Triceps':
        return 'TRI';
      case 'Quads':
        return 'QUAD';
      case 'Hamstrings':
        return 'HAM';
      case 'Glutes':
        return 'GLUT';
      case 'Calves':
      case 'Calf':
        return 'CALF';
      case 'Abs':
        return 'ABS';
      case 'Other':
        return 'OTHR';
      default:
        return muscleGroup.length <= 4
            ? muscleGroup.toUpperCase()
            : muscleGroup.substring(0, 4).toUpperCase();
    }
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
