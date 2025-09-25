import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MuscleBarChartWidget extends StatelessWidget {
  final Map<String, int> muscleGroupCounts;

  const MuscleBarChartWidget({
    Key? key,
    required this.muscleGroupCounts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (muscleGroupCounts.isEmpty || muscleGroupCounts.values.every((count) => count == 0)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            Text(
              'No muscle data available',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return _buildBarChart();
  }

  Widget _buildBarChart() {
    // Ordna muskelgrupperna alfabetiskt
    final sortedEntries = muscleGroupCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxValue = muscleGroupCounts.values.reduce((a, b) => a > b ? a : b).toDouble();

    final barGroups = sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final muscleEntry = entry.value;
      final muscleGroup = muscleEntry.key;
      final count = muscleEntry.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: _getMuscleColor(muscleGroup),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            gradient: LinearGradient(
              colors: [
                _getMuscleColor(muscleGroup),
                _getMuscleColor(muscleGroup).withOpacity(0.7),
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
        maxY: maxValue * 1.1, // Lite extra space ovanför högsta värdet
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade800.withOpacity(0.3),
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  final muscleGroup = sortedEntries[index].key;
                  // Använd förkortningar för att få plats
                  final shortName = _getShortName(muscleGroup);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      shortName,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxValue / 4,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => const Color(0xFF18181B),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final muscleGroup = sortedEntries[group.x.toInt()].key;
              final count = rod.toY.toInt();
              return BarTooltipItem(
                '$muscleGroup\n$count sets',
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

  String _getShortName(String muscleGroup) {
    switch (muscleGroup) {
      case 'Shoulders': return 'SHLD';
      case 'Biceps': return 'BIC';
      case 'Triceps': return 'TRI';
      case 'Chest': return 'CHT';
      case 'Back': return 'BCK';
      case 'Quads': return 'QUAD';
      case 'Hamstrings': return 'HAM';
      case 'Glutes': return 'GLUT';
      case 'Abs': return 'ABS';
      default: return muscleGroup.substring(0, 3).toUpperCase();
    }
  }

  Color _getMuscleColor(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest': return const Color(0xFFDC2626);
      case 'Back': return const Color(0xFF16A34A);
      case 'Shoulders': return const Color(0xFF2563EB);
      case 'Biceps': return const Color(0xFF7C3AED);
      case 'Triceps': return const Color(0xFFEAB308);
      case 'Quads': return const Color(0xFFE11D48);
      case 'Hamstrings': return const Color(0xFFDC2F02);
      case 'Glutes': return const Color(0xFFB91C1C);
      case 'Abs': return const Color(0xFF06B6D4);
      default: return Colors.grey;
    }
  }
}