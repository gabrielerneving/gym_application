import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import 'ui/ui.dart';

/// ---------------------------------------------------------------------------
/// Building blocks shared by the statistics screens.
///
/// They sit next to the kit rather than inside it because only the stats area
/// uses them so far. Each one exists because the kit piece it resembles does
/// something the stats screens must not do: a [StatGrid] of equal tiles turns
/// one highlighted tile into "the selected one", and [StatBar] colours its
/// value with the bar tone and draws a target band as a second filled bar.
/// ---------------------------------------------------------------------------

/// One secondary number in a [StatsHeadlineCard].
class HeadlineMetric {
  final String label;
  final String value;
  final String? unit;

  /// Change against the previous period; hidden when null.
  final num? delta;
  final bool deltaIsPercent;

  const HeadlineMetric({
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.deltaIsPercent = true,
  });
}

/// A screen's headline: one big number that is clearly *the* number, with its
/// change, and a quiet row of supporting numbers under a hairline.
///
/// Flat on purpose. Hierarchy comes from size, not from painting one of four
/// equal tiles with the gradient — which read as a selected tab.
class StatsHeadlineCard extends ConsumerWidget {
  final double value;
  final int decimals;

  /// Overrides [decimals] — for compact tonnage ("118k").
  final String Function(double value)? format;

  /// The word after the number: "workouts", "kg", "week streak".
  final String unit;

  final IconData? icon;
  final num? delta;
  final bool deltaIsPercent;

  /// One line under the number, for context the number cannot carry.
  final String? caption;

  final List<HeadlineMetric> metrics;
  final VoidCallback? onTap;

  const StatsHeadlineCard({
    super.key,
    required this.value,
    required this.unit,
    this.decimals = 0,
    this.format,
    this.icon,
    this.delta,
    this.deltaIsPercent = true,
    this.caption,
    this.metrics = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    // Four numbers read best as a 2×2 block; anything else as one row.
    final columns = metrics.length == 4 ? 2 : math.min(3, metrics.length);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 26, color: t.primary),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    CountUp(
                      value: value,
                      decimals: decimals,
                      format: format,
                      style: AppType.metric(t, size: 44),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(t).copyWith(
                          color: t.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null) ...[
                const SizedBox(width: AppSpacing.sm),
                DeltaBadge(
                  delta: delta!,
                  percent: deltaIsPercent,
                  fontSize: 12.5,
                ),
              ],
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(caption!, style: AppType.secondary(t)),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(height: 1, thickness: 1, color: t.divider),
            const SizedBox(height: AppSpacing.lg),
            for (var row = 0; row * columns < metrics.length; row++) ...[
              if (row > 0) const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: row * columns + c < metrics.length
                          ? _MetricCell(metric: metrics[row * columns + c])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetricCell extends ConsumerWidget {
  final HeadlineMetric metric;

  const _MetricCell({required this.metric});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption(t).copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.metric(t, size: 21).copyWith(letterSpacing: -0.6),
              ),
            ),
            if (metric.unit != null) ...[
              const SizedBox(width: 3),
              Text(metric.unit!, style: AppType.caption(t)),
            ],
          ],
        ),
        if (metric.delta != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          DeltaBadge(
            delta: metric.delta!,
            percent: metric.deltaIsPercent,
            compact: true,
            fontSize: 11.5,
          ),
        ],
      ],
    );
  }
}

/// A labelled bar whose value stays in plain text and whose optional target
/// range is drawn as two tick marks on the track — a ruler, not a second bar.
///
/// ```dart
/// RangeBar(
///   label: 'Back',
///   valueLabel: '9.8/wk',
///   value: 9.8,
///   max: 24,
///   rangeMin: 10,
///   rangeMax: 20,
/// )
/// ```
class RangeBar extends ConsumerWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double max;

  /// Bar fill. Defaults to the primary colour.
  final Color? color;

  /// Value text colour. Defaults to body text — colour lives on the bar.
  final Color? valueColor;

  /// Drawn just before the value, e.g. a check for "on target".
  final IconData? valueIcon;
  final Color? valueIconColor;

  final double? rangeMin;
  final double? rangeMax;

  /// One quiet line under the bar.
  final String? caption;

  const RangeBar({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.max,
    this.color,
    this.valueColor,
    this.valueIcon,
    this.valueIconColor,
    this.rangeMin,
    this.rangeMax,
    this.caption,
  });

  static const double _trackHeight = 8;
  static const double _tickOverhang = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = color ?? t.primary;
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final hasRange = rangeMin != null && rangeMax != null && max > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(t).copyWith(fontSize: 14.5),
                ),
              ),
              if (valueIcon != null) ...[
                Icon(valueIcon, size: 15, color: valueIconColor ?? tone),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                valueLabel,
                style: AppType.mono(t, size: 14)
                    .copyWith(color: valueColor ?? t.text),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm - _tickOverhang),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              double xOf(double v) => width * (v / max).clamp(0.0, 1.0);

              Widget tick(double v) => Positioned(
                    left: (xOf(v) - 1).clamp(0.0, width - 2),
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.textSecondary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  );

              return SizedBox(
                height: _trackHeight + 2 * _tickOverhang,
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: _tickOverhang,
                      bottom: _tickOverhang,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    if (hasRange)
                      Positioned(
                        left: xOf(rangeMin!),
                        width: math.max(0.0, xOf(rangeMax!) - xOf(rangeMin!)),
                        top: _tickOverhang,
                        bottom: _tickOverhang,
                        child: ColoredBox(
                          color: t.textSecondary.withValues(alpha: 0.10),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      top: _tickOverhang,
                      bottom: _tickOverhang,
                      right: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: fraction),
                          duration: AppMotion.lazy,
                          curve: AppMotion.enter,
                          builder: (context, f, _) => Container(
                            width: width * f,
                            decoration: BoxDecoration(
                              color: tone,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (hasRange) ...[tick(rangeMin!), tick(rangeMax!)],
                  ],
                ),
              );
            },
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs + 2 - _tickOverhang),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption(t),
            ),
          ],
        ],
      ),
    );
  }
}

/// The small legend glyph for a [RangeBar] range: a faint strip between two
/// ticks.
class RangeLegendGlyph extends ConsumerWidget {
  const RangeLegendGlyph({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tick = Container(
      width: 2,
      height: 14,
      decoration: BoxDecoration(
        color: t.textSecondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(1),
      ),
    );
    return SizedBox(
      width: 26,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 8,
            color: t.textSecondary.withValues(alpha: 0.10),
          ),
          Align(alignment: Alignment.centerLeft, child: tick),
          Align(alignment: Alignment.centerRight, child: tick),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Muscle balance, in words.
/// ---------------------------------------------------------------------------

/// How each group's bar is coloured. Colour only where it means something:
/// inside the band is good news, above it is worth a look, and below it is
/// simply work in progress — neutral, not a warning.
Color muscleStatusColor(AppColors t, VolumeStatus status) => switch (status) {
      VolumeStatus.none => t.textTertiary,
      VolumeStatus.low => t.textSecondary.withValues(alpha: t.isDark ? 0.55 : 0.45),
      VolumeStatus.optimal => t.success,
      VolumeStatus.high => t.warning,
    };

/// Distance from the band in sets a week; 0 inside it.
double _distanceToBand(MuscleBalance m) {
  if (m.setsPerWeek < m.targetMin) return m.targetMin - m.setsPerWeek;
  if (m.setsPerWeek > m.targetMax) return m.setsPerWeek - m.targetMax;
  return 0;
}

/// A headline and one supporting line for the state of the muscle balance,
/// led by what is going right: the groups on target, or the ones closest.
class MuscleBalanceSummary {
  final String title;
  final String subtitle;

  /// The groups worth a bar in a short list: on target first, then the ones
  /// nearest the band.
  final List<MuscleBalance> closest;

  /// Trained groups furthest below the band — "room to grow".
  final List<MuscleBalance> roomToGrow;

  const MuscleBalanceSummary._({
    required this.title,
    required this.subtitle,
    required this.closest,
    required this.roomToGrow,
  });

  factory MuscleBalanceSummary.of(
    List<MuscleBalance> balance,
    TrainingGoals goals, {
    int show = 3,
  }) {
    final trained = balance.where((m) => m.totalSets > 0).toList();
    final onTarget =
        balance.where((m) => m.status == VolumeStatus.optimal).toList();

    final ranked = [...trained]..sort((a, b) {
        final byDistance = _distanceToBand(a).compareTo(_distanceToBand(b));
        return byDistance != 0
            ? byDistance
            : b.setsPerWeek.compareTo(a.setsPerWeek);
      });
    final closest = ranked.take(show).toList();
    final closestNames = {for (final m in closest) m.group};
    final roomToGrow = AnalyticsService.weakestGroups(balance)
        .where((m) => !closestNames.contains(m.group))
        .toList();

    if (trained.isEmpty) {
      return const MuscleBalanceSummary._(
        title: 'No muscle groups yet',
        subtitle: 'Link your exercises to muscle groups and this fills in.',
        closest: [],
        roomToGrow: [],
      );
    }

    if (onTarget.length == balance.length) {
      return MuscleBalanceSummary._(
        title: 'Every group on target',
        subtitle: 'All ${balance.length} inside ${goals.bandSentence}',
        closest: closest,
        roomToGrow: roomToGrow,
      );
    }

    if (onTarget.isNotEmpty) {
      return MuscleBalanceSummary._(
        title: '${onTarget.length} of ${balance.length} groups on target',
        subtitle: '${_names(onTarget.map((m) => m.group).toList())} '
            '${onTarget.length == 1 ? 'is' : 'are'} inside '
            '${goals.bandSentence}',
        closest: closest,
        roomToGrow: roomToGrow,
      );
    }

    // Nothing inside the band yet: lead with whatever is nearest, and how near.
    final nearest = ranked.first;
    final tied = ranked
        .where((m) =>
            m.status == nearest.status &&
            (_distanceToBand(m) - _distanceToBand(nearest)).abs() < 0.05)
        .map((m) => m.group)
        .toList();
    final verb = tied.length == 1 ? 'is' : 'are';

    if (nearest.status == VolumeStatus.high) {
      return MuscleBalanceSummary._(
        title: '${_names(tied)} $verb just above target',
        subtitle: 'Target ${goals.bandSentence}',
        closest: closest,
        roomToGrow: roomToGrow,
      );
    }

    final gap = math.max(1, nearest.setsToTarget);
    return MuscleBalanceSummary._(
      title: '${_names(tied)} $verb $gap ${gap == 1 ? 'set' : 'sets'} '
          'from target',
      subtitle: 'Target ${goals.bandSentence}',
      closest: closest,
      roomToGrow: roomToGrow,
    );
  }

  /// "Back", "Back and Chest", "Back, Chest and 2 more".
  static String _names(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    if (names.length == 3) return '${names[0]}, ${names[1]} and ${names[2]}';
    return '${names[0]}, ${names[1]} and ${names.length - 2} more';
  }
}

/// ---------------------------------------------------------------------------
/// Chart axes
/// ---------------------------------------------------------------------------

/// Round-number bounds and a step for a value axis, so every label sits on a
/// gridline and reads "120, 130, 140" rather than "122.9, 130.6".
class NiceAxis {
  final double min;
  final double max;
  final double step;

  const NiceAxis._(this.min, this.max, this.step);

  /// Covers [low]–[high] in roughly [intervals] steps of 1, 2, 2.5 or 5 × 10ⁿ.
  /// [fromZero] pins the floor to zero (tonnage, counts).
  factory NiceAxis.of(
    double low,
    double high, {
    int intervals = 3,
    bool fromZero = false,
  }) {
    if (fromZero) low = math.min(0, low);
    if (!low.isFinite || !high.isFinite) return const NiceAxis._(0, 1, 1);
    if (high - low <= 0) {
      final pad = high.abs() > 0 ? high.abs() * 0.1 : 1.0;
      low = fromZero ? low : low - pad;
      high = high + pad;
    }

    final step = niceStep((high - low) / intervals);
    var min = (low / step).floorToDouble() * step;
    final max = (high / step).ceilToDouble() * step;
    if (low >= 0 && min < 0) min = 0;
    return NiceAxis._(min, max == min ? min + step : max, step);
  }

  /// 1, 2, 2.5 or 5 times a power of ten, at least [raw].
  static double niceStep(double raw) {
    if (raw <= 0 || !raw.isFinite) return 1;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final n = raw / magnitude;
    final nice = n <= 1
        ? 1.0
        : n <= 2
            ? 2.0
            : n <= 2.5
                ? 2.5
                : n <= 5
                    ? 5.0
                    : 10.0;
    return nice * magnitude;
  }

  /// True when [value] lands on a tick — fl_chart also asks for a label at
  /// the raw axis ends, and those should stay blank.
  bool isTick(double value) {
    final k = (value - min) / step;
    return (k - k.round()).abs() < 1e-6;
  }
}
