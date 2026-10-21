import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'stats_components.dart';
import 'ui/ui.dart';

/// ---------------------------------------------------------------------------
/// The shared progression line chart.
///
/// It plots one or more [ProgressionSeries] against a real time axis, so two
/// exercises logged on different days line up honestly instead of being forced
/// onto a shared session index.
///
/// Everything visual comes from the theme: the line takes the series colour,
/// the area fill uses [AppColors.chartFillGradient], grid lines are hairlines
/// in [AppColors.divider] and axis labels sit in [AppColors.textTertiary], so
/// the chart stays legible on the light and the dark palettes alike. The value
/// axis uses round steps ([NiceAxis]) so every label sits on a gridline.
/// ---------------------------------------------------------------------------
class ProgressionSeries {
  /// Shown in the legend and in the tooltip when more than one line is drawn.
  final String label;

  /// One entry per session, oldest first. Must line up with [values].
  final List<DateTime> dates;
  final List<double> values;

  final Color color;

  /// Appended to tooltip values — 'kg', '%', 'reps'.
  final String unit;

  const ProgressionSeries({
    required this.label,
    required this.dates,
    required this.values,
    required this.color,
    this.unit = 'kg',
  });

  /// Defensive: never read past the shorter of the two lists.
  int get length => math.min(dates.length, values.length);

  bool get isEmpty => length == 0;
  bool get isNotEmpty => length > 0;
}

class ProgressionChartWidget extends ConsumerStatefulWidget {
  final List<ProgressionSeries> series;

  /// Height of the plot area (the legend adds to this).
  final double height;

  /// Drawn above the chart when there is more than one series.
  final bool showLegend;

  /// Gradient area under the line. Only ever painted for a single series —
  /// two overlapping fills turn to mud.
  final bool showArea;

  /// Grows the line up from the baseline on first build.
  final bool animate;

  final String emptyMessage;

  /// Overrides the left axis label format. Defaults to compact numbers.
  final String Function(double value)? axisLabel;

  const ProgressionChartWidget({
    super.key,
    required this.series,
    this.height = 220,
    this.showLegend = true,
    this.showArea = true,
    this.animate = true,
    this.emptyMessage = 'No sessions to plot yet',
    this.axisLabel,
  });

  @override
  ConsumerState<ProgressionChartWidget> createState() =>
      _ProgressionChartWidgetState();
}

class _ProgressionChartWidgetState extends ConsumerState<ProgressionChartWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.lazy,
  );

  late final Animation<double> _reveal = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant ProgressionChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Replay the entrance when the plotted data actually changes (a different
    // exercise, a different metric) — not on every incidental rebuild.
    if (widget.animate &&
        _signature(oldWidget.series) != _signature(widget.series)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _signature(List<ProgressionSeries> series) =>
      series.map((s) => '${s.label}#${s.length}#${s.unit}').join('|');

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final series = widget.series.where((s) => s.isNotEmpty).toList();

    if (series.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded, size: 26, color: t.textTertiary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.emptyMessage,
                textAlign: TextAlign.center,
                style: AppType.secondary(t),
              ),
            ],
          ),
        ),
      );
    }

    final geometry = _ChartGeometry.of(series);
    final showDots = geometry.totalPoints <= 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLegend && series.length > 1) ...[
          _ChartLegend(series: series),
          const SizedBox(height: AppSpacing.lg),
        ],
        SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) {
              final progress = _reveal.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: (progress * 1.8).clamp(0.0, 1.0),
                child: LineChart(
                  _chartData(t, series, geometry, progress, showDots),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Chart configuration ---------------------------------------------------

  LineChartData _chartData(
    AppColors t,
    List<ProgressionSeries> series,
    _ChartGeometry g,
    double progress,
    bool showDots,
  ) {
    final labelStyle = AppType.caption(t).copyWith(
      fontSize: 10.5,
      color: t.textTertiary,
      fontWeight: FontWeight.w600,
    );

    return LineChartData(
      minX: g.minX,
      maxX: g.maxX,
      minY: g.minY,
      maxY: g.maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        drawHorizontalLine: true,
        horizontalInterval: g.yInterval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: t.divider,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            interval: g.yInterval,
            getTitlesWidget: (value, meta) {
              if (!g.axis.isTick(value)) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  _formatAxis(value),
                  textAlign: TextAlign.right,
                  style: labelStyle,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: g.xInterval,
            // The raw ends of the axis are padding, not dates worth naming —
            // labelled, they landed on top of the first real tick.
            minIncluded: false,
            maxIncluded: false,
            getTitlesWidget: (value, meta) {
              // A single session has no span to label — one date is enough.
              if (g.singlePoint && value.abs() > 0.01) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: AppSpacing.sm,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(
                  AppFormat.dayMonth(g.dateAt(value)),
                  style: labelStyle,
                ),
              );
            },
          ),
        ),
      ),
      // The top and bottom ticks get the lines the grid leaves out.
      borderData: FlBorderData(
        show: true,
        border: Border(
          top: BorderSide(color: t.divider),
          bottom: BorderSide(color: t.outline),
        ),
      ),
      lineBarsData: [
        for (var i = 0; i < series.length; i++)
          _barData(
            t,
            series[i],
            g,
            progress,
            showDots,
            fill: widget.showArea && series.length == 1,
          ),
      ],
      lineTouchData: _touchData(t, series, g),
    );
  }

  String _formatAxis(double value) {
    final formatter = widget.axisLabel;
    if (formatter != null) return formatter(value);
    return AppFormat.compact(value);
  }

  LineChartBarData _barData(
    AppColors t,
    ProgressionSeries s,
    _ChartGeometry g,
    double progress,
    bool showDots, {
    required bool fill,
  }) {
    // Grow every point up from the floor of the chart as the entrance plays.
    final spots = <FlSpot>[
      for (var i = 0; i < s.length; i++)
        FlSpot(
          g.xOf(s.dates[i]),
          g.minY + (s.values[i] - g.minY) * progress,
        ),
    ];

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      // Without this a jump between two close sessions swings past both
      // points before settling — a wobble the data does not have.
      preventCurveOverShooting: true,
      color: s.color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: showDots && progress > 0.995,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 3.4,
          color: s.color,
          strokeWidth: 2,
          strokeColor: t.card,
        ),
      ),
      belowBarData: BarAreaData(
        show: fill,
        gradient: s.color == t.primary
            ? t.chartFillGradient
            : _fillGradient(s.color, t.isDark),
      ),
    );
  }

  LinearGradient _fillGradient(Color color, bool isDark) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isDark ? 0.32 : 0.24),
          color.withValues(alpha: 0.0),
        ],
      );

  LineTouchData _touchData(
    AppColors t,
    List<ProgressionSeries> series,
    _ChartGeometry g,
  ) {
    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
        if (event is FlTapDownEvent &&
            response?.lineBarSpots != null &&
            response!.lineBarSpots!.isNotEmpty) {
          HapticFeedback.selectionClick();
        }
      },
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) => t.elevated,
        tooltipRoundedRadius: AppRadius.sm,
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return <LineTooltipItem?>[
            for (final spot in touchedSpots) _tooltipItem(t, series, g, spot),
          ];
        },
      ),
      getTouchedSpotIndicator: (barData, spotIndexes) {
        final tone = barData.color ?? t.primary;
        return spotIndexes.map((spotIndex) {
          return TouchedSpotIndicatorData(
            FlLine(color: tone.withValues(alpha: 0.35), strokeWidth: 1.5),
            FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 5,
                color: tone,
                strokeWidth: 2,
                strokeColor: t.card,
              ),
            ),
          );
        }).toList();
      },
    );
  }

  LineTooltipItem _tooltipItem(
    AppColors t,
    List<ProgressionSeries> series,
    _ChartGeometry g,
    LineBarSpot spot,
  ) {
    final barIndex =
        (spot.barIndex < 0 || spot.barIndex >= series.length) ? 0 : spot.barIndex;
    final s = series[barIndex];
    final index = g.nearestIndex(s, spot.x);
    final value = s.values[index];
    final date = s.dates[index];

    final prefix = series.length > 1 ? '${s.label}\n' : '';
    final unit = s.unit.isEmpty ? '' : ' ${s.unit}';

    return LineTooltipItem(
      '$prefix${AppFormat.weight(value)}$unit\n${AppFormat.dayMonth(date)}',
      TextStyle(
        color: s.color,
        fontWeight: FontWeight.w700,
        fontSize: 11.5,
        height: 1.45,
      ),
    );
  }
}

/// Everything the chart needs to place a point: the time origin, the padded
/// axis bounds and the label intervals.
class _ChartGeometry {
  final DateTime origin;
  final double minX;
  final double maxX;
  final NiceAxis axis;
  final double xInterval;

  /// True when every point falls on (roughly) the same day.
  final bool singlePoint;

  final int totalPoints;

  const _ChartGeometry({
    required this.origin,
    required this.minX,
    required this.maxX,
    required this.axis,
    required this.xInterval,
    required this.singlePoint,
    required this.totalPoints,
  });

  double get minY => axis.min;
  double get maxY => axis.max;
  double get yInterval => axis.step;

  factory _ChartGeometry.of(List<ProgressionSeries> series) {
    DateTime? first;
    DateTime? last;
    var lowest = double.infinity;
    var highest = -double.infinity;
    var total = 0;

    for (final s in series) {
      for (var i = 0; i < s.length; i++) {
        final date = s.dates[i];
        final value = s.values[i];
        if (first == null || date.isBefore(first)) first = date;
        if (last == null || date.isAfter(last)) last = date;
        if (value < lowest) lowest = value;
        if (value > highest) highest = value;
        total++;
      }
    }

    final start = first ?? DateTime.now();
    final end = last ?? start;
    final span = end.difference(start).inMinutes / 1440.0;

    if (total == 0) {
      lowest = 0.0;
      highest = 1.0;
    }

    // Round-number bounds a little outside the data, so the line rarely
    // touches the frame and every label names a gridline.
    final pad = (highest - lowest) * 0.06;
    final axis = NiceAxis.of(
      lowest >= 0 ? math.max(0.0, lowest - pad) : lowest - pad,
      highest + pad,
    );

    final singlePoint = span < 0.75;
    final minX = singlePoint ? -1.0 : -span * 0.03;
    final maxX = singlePoint ? 1.0 : span * 1.03;

    return _ChartGeometry(
      origin: start,
      minX: minX,
      maxX: maxX,
      axis: axis,
      // Whole-day steps keep the date labels distinct; rounding down keeps
      // the fourth label (three steps on) inside the data.
      xInterval: singlePoint ? 1.0 : math.max(1.0, (span / 3).floorToDouble()),
      singlePoint: singlePoint,
      totalPoints: total,
    );
  }

  /// Days elapsed since [origin] — the chart's x coordinate.
  double xOf(DateTime date) => date.difference(origin).inMinutes / 1440.0;

  DateTime dateAt(double x) =>
      origin.add(Duration(minutes: (x * 1440).round()));

  /// Maps a touched x back onto the closest real session in [s].
  int nearestIndex(ProgressionSeries s, double x) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < s.length; i++) {
      final distance = (xOf(s.dates[i]) - x).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }
}

/// Colour key for a multi-series chart.
class _ChartLegend extends ConsumerWidget {
  final List<ProgressionSeries> series;

  const _ChartLegend({required this.series});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.secondary(t).copyWith(
                    color: t.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
