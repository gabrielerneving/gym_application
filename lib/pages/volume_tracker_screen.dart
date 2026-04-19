import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';

enum VolumePeriod { oneWeek, oneMonth, threeMonths }

class VolumeTrackerScreen extends ConsumerStatefulWidget {
  const VolumeTrackerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<VolumeTrackerScreen> createState() =>
      _VolumeTrackerScreenState();
}

class _VolumeTrackerScreenState extends ConsumerState<VolumeTrackerScreen> {
  DatabaseService? _dbService;

  VolumePeriod selectedPeriod = VolumePeriod.oneMonth;
  // null = "All muscles"
  String? selectedMuscleGroup;

  bool isLoading = true;

  // Current period totals per muscle
  Map<String, int> currentCounts = {};
  // Previous period totals per muscle (for delta)
  Map<String, int> previousCounts = {};
  // Time-bucketed counts for selected muscle trend chart
  List<_TimeBucket> timeBuckets = [];

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _dbService = DatabaseService(uid: user.uid);
      await _loadData();
    } else {
      setState(() => isLoading = false);
    }
  }

  _PeriodRange _rangeForPeriod(VolumePeriod period, {int offset = 0}) {
    final now = DateTime.now();
    final endOfToday =
        DateTime(now.year, now.month, now.day, 23, 59, 59);

    late int days;
    switch (period) {
      case VolumePeriod.oneWeek:
        days = 7;
        break;
      case VolumePeriod.oneMonth:
        days = 30;
        break;
      case VolumePeriod.threeMonths:
        days = 90;
        break;
    }

    final end = endOfToday.subtract(Duration(days: days * offset));
    final start = DateTime(end.year, end.month, end.day)
        .subtract(Duration(days: days - 1));

    return _PeriodRange(start: start, end: end);
  }

  // Build time buckets within a period for the trend chart.
  // 1 week -> 7 daily buckets
  // 1 month -> ~5 weekly buckets
  // 3 months -> ~12 weekly buckets
  List<_TimeBucket> _buildTimeBuckets(_PeriodRange range, VolumePeriod period) {
    final buckets = <_TimeBucket>[];
    final startDay = DateTime(range.start.year, range.start.month, range.start.day);
    final endDay = DateTime(range.end.year, range.end.month, range.end.day);
    final totalDays = endDay.difference(startDay).inDays + 1;

    if (period == VolumePeriod.oneWeek) {
      for (int i = 0; i < totalDays; i++) {
        final d = startDay.add(Duration(days: i));
        buckets.add(_TimeBucket(
          start: DateTime(d.year, d.month, d.day),
          end: DateTime(d.year, d.month, d.day, 23, 59, 59),
          label: DateFormat('E').format(d),
        ));
      }
    } else {
      const bucketSizeDays = 7;
      DateTime cursor = startDay;
      while (!cursor.isAfter(endDay)) {
        final bucketEndDay = cursor.add(const Duration(days: bucketSizeDays - 1));
        final clampedEndDay = bucketEndDay.isAfter(endDay) ? endDay : bucketEndDay;
        buckets.add(_TimeBucket(
          start: cursor,
          end: DateTime(
              clampedEndDay.year, clampedEndDay.month, clampedEndDay.day, 23, 59, 59),
          label: DateFormat('d/M').format(cursor),
        ));
        cursor = cursor.add(const Duration(days: bucketSizeDays));
      }
    }

    return buckets;
  }

  Future<void> _loadData() async {
    if (_dbService == null) return;
    setState(() => isLoading = true);

    try {
      final current = _rangeForPeriod(selectedPeriod);
      final previous = _rangeForPeriod(selectedPeriod, offset: 1);

      // Bucket 0 = current totals, bucket 1 = previous totals.
      final overviewBuckets = await _dbService!.getMuscleGroupCountsByBuckets(
        bucketStarts: [current.start, previous.start],
        bucketEnds: [current.end, previous.end],
      );

      final curr = overviewBuckets[0];
      final prev = overviewBuckets[1];

      // Time-bucket breakdown across the current period.
      final tBuckets = _buildTimeBuckets(current, selectedPeriod);
      final bucketCounts = await _dbService!.getMuscleGroupCountsByBuckets(
        bucketStarts: tBuckets.map((b) => b.start).toList(),
        bucketEnds: tBuckets.map((b) => b.end).toList(),
      );
      for (int i = 0; i < tBuckets.length; i++) {
        tBuckets[i].countsByMuscle = bucketCounts[i];
      }

      if (mounted) {
        setState(() {
          currentCounts = curr;
          previousCounts = prev;
          timeBuckets = tBuckets;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading volume data: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  int get _currentTotal => _sumFor(currentCounts, selectedMuscleGroup);
  int get _previousTotal => _sumFor(previousCounts, selectedMuscleGroup);

  int _sumFor(Map<String, int> counts, String? muscle) {
    if (muscle != null) return counts[muscle] ?? 0;
    return counts.values.fold<int>(0, (sum, v) => sum + v);
  }

  String _periodLabel(VolumePeriod p) {
    switch (p) {
      case VolumePeriod.oneWeek:
        return '1 week';
      case VolumePeriod.oneMonth:
        return '1 month';
      case VolumePeriod.threeMonths:
        return '3 months';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: theme.primary.withOpacity(0.8), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Volume Tracker',
          style: TextStyle(
            color: theme.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : RefreshIndicator(
              color: theme.primary,
              backgroundColor: theme.card,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(theme),
                    const SizedBox(height: 16),
                    _buildMuscleFilter(theme),
                    const SizedBox(height: 20),
                    _buildSummaryCard(theme),
                    const SizedBox(height: 20),
                    _buildChartCard(theme),
                    const SizedBox(height: 20),
                    if (selectedMuscleGroup == null)
                      _buildBreakdownList(theme),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(dynamic theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.textSecondary.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: VolumePeriod.values.map((p) {
          final selected = selectedPeriod == p;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (selectedPeriod == p) return;
                HapticFeedback.lightImpact();
                setState(() => selectedPeriod = p);
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _periodLabel(p),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : theme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMuscleFilter(dynamic theme) {
    final options = <String?>[null, ...DatabaseService.muscleGroups];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final muscle = options[i];
          final selected = selectedMuscleGroup == muscle;
          final label = muscle ?? 'All';
          return GestureDetector(
            onTap: () {
              if (selectedMuscleGroup == muscle) return;
              HapticFeedback.lightImpact();
              setState(() => selectedMuscleGroup = muscle);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? (muscle == null
                        ? theme.primary
                        : _getMuscleColor(muscle))
                    : theme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : theme.textSecondary.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : theme.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(dynamic theme) {
    final current = _currentTotal;
    final previous = _previousTotal;
    final diff = current - previous;
    final pctText = previous == 0
        ? (current > 0 ? '—' : '0%')
        : '${((diff / previous) * 100).toStringAsFixed(0)}%';
    final positive = diff > 0;
    final negative = diff < 0;
    final deltaColor = positive
        ? const Color(0xFF16A34A)
        : negative
            ? const Color(0xFFDC2626)
            : theme.textSecondary;
    final deltaIcon = positive
        ? Icons.arrow_upward
        : negative
            ? Icons.arrow_downward
            : Icons.remove;

    final titleLabel = selectedMuscleGroup == null
        ? 'All working sets'
        : '${selectedMuscleGroup!} working sets';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.textSecondary.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleLabel,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$current',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'sets',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(deltaIcon, color: deltaColor, size: 18),
              const SizedBox(width: 4),
              Text(
                '${diff > 0 ? '+' : ''}$diff ($pctText)',
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'vs previous ${_periodLabel(selectedPeriod).toLowerCase()}',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(dynamic theme) {
    final title = selectedMuscleGroup == null
        ? 'Sets per muscle group'
        : '${selectedMuscleGroup!} over time';

    return Container(
      height: 340,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.textSecondary.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: selectedMuscleGroup == null
                ? _buildMuscleComparisonChart(theme)
                : _buildTrendChart(theme, selectedMuscleGroup!),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleComparisonChart(dynamic theme) {
    final entries = currentCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return _emptyChartState(theme, 'No sets logged in this period');
    }

    final maxValue =
        entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    final barGroups = entries.asMap().entries.map((entry) {
      final index = entry.key;
      final muscle = entry.value.key;
      final count = entry.value.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            gradient: LinearGradient(
              colors: [
                _getMuscleColor(muscle),
                _getMuscleColor(muscle).withOpacity(0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.15,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 4 ? (maxValue / 4) : 1.0,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade800.withOpacity(0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) return const Text('');
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    _shortName(entries[i].key),
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxValue > 4 ? (maxValue / 4) : 1.0,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(color: theme.textSecondary, fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapDownEvent && response?.spot != null) {
              HapticFeedback.lightImpact();
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E1E1E),
            getTooltipItem: (group, _, rod, __) {
              final muscle = entries[group.x.toInt()].key;
              return BarTooltipItem(
                '$muscle\n${rod.toY.toInt()} sets',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(dynamic theme, String muscle) {
    if (timeBuckets.isEmpty) {
      return _emptyChartState(theme, 'No sets logged in this period');
    }

    final values =
        timeBuckets.map((b) => b.countsByMuscle[muscle] ?? 0).toList();
    final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m).toDouble();

    if (maxValue == 0) {
      return _emptyChartState(theme, 'No ${muscle.toLowerCase()} sets yet');
    }

    final color = _getMuscleColor(muscle);

    final barGroups = List.generate(timeBuckets.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: values[i].toDouble(),
            width: timeBuckets.length > 10 ? 10 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ],
      );
    });

    final labelStep = timeBuckets.length > 7
        ? (timeBuckets.length / 6).ceil()
        : 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.15,
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 4 ? (maxValue / 4) : 1.0,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade800.withOpacity(0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= timeBuckets.length) return const Text('');
                if (i % labelStep != 0 && i != timeBuckets.length - 1) {
                  return const Text('');
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    timeBuckets[i].label,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxValue > 4 ? (maxValue / 4) : 1.0,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(color: theme.textSecondary, fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (event is FlTapDownEvent && response?.spot != null) {
              HapticFeedback.lightImpact();
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E1E1E),
            getTooltipItem: (group, _, rod, __) {
              final bucket = timeBuckets[group.x.toInt()];
              return BarTooltipItem(
                '${bucket.label}\n${rod.toY.toInt()} sets',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _emptyChartState(dynamic theme, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 40, color: theme.textSecondary),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownList(dynamic theme) {
    final entries = currentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalCurrent = _currentTotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.textSecondary.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakdown',
            style: TextStyle(
              color: theme.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map((e) =>
              _buildBreakdownRow(theme, e.key, e.value, totalCurrent)),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
      dynamic theme, String muscle, int current, int total) {
    final previous = previousCounts[muscle] ?? 0;
    final diff = current - previous;
    final percentage = total == 0 ? 0.0 : (current / total) * 100;
    final positive = diff > 0;
    final negative = diff < 0;
    final deltaColor = positive
        ? const Color(0xFF16A34A)
        : negative
            ? const Color(0xFFDC2626)
            : theme.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getMuscleColor(muscle),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                muscle.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        muscle,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$current sets',
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.textSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (percentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getMuscleColor(muscle),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      diff == 0 ? '±0' : '${diff > 0 ? '+' : ''}$diff',
                      style: TextStyle(
                        color: deltaColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortName(String muscleGroup) {
    switch (muscleGroup) {
      case 'Shoulders':
        return 'SHLD';
      case 'Biceps':
        return 'BIC';
      case 'Triceps':
        return 'TRI';
      case 'Chest':
        return 'CHT';
      case 'Back':
        return 'BCK';
      case 'Quads':
        return 'QUAD';
      case 'Hamstrings':
        return 'HAM';
      case 'Glutes':
        return 'GLUT';
      case 'Calves':
        return 'CALF';
      case 'Abs':
        return 'ABS';
      default:
        return muscleGroup.substring(0, 3).toUpperCase();
    }
  }

  Color _getMuscleColor(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest':
        return const Color(0xFFDC2626);
      case 'Back':
        return const Color(0xFF16A34A);
      case 'Shoulders':
        return const Color(0xFF2563EB);
      case 'Biceps':
        return const Color(0xFF7C3AED);
      case 'Triceps':
        return const Color(0xFFEAB308);
      case 'Quads':
        return const Color(0xFFE11D48);
      case 'Hamstrings':
        return const Color(0xFFDC2F02);
      case 'Glutes':
        return const Color(0xFFB91C1C);
      case 'Calves':
        return const Color(0xFFEA580C);
      case 'Abs':
        return const Color(0xFF06B6D4);
      default:
        return Colors.grey;
    }
  }
}

class _PeriodRange {
  final DateTime start;
  final DateTime end;
  _PeriodRange({required this.start, required this.end});
}

class _TimeBucket {
  final DateTime start;
  final DateTime end;
  final String label;
  Map<String, int> countsByMuscle;

  _TimeBucket({
    required this.start,
    required this.end,
    required this.label,
    Map<String, int>? countsByMuscle,
  }) : countsByMuscle = countsByMuscle ?? {};
}
