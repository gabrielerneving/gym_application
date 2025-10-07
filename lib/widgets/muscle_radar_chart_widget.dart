import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class MuscleRadarChartWidget extends ConsumerWidget {
  final Map<String, int> muscleGroupCounts;

  const MuscleRadarChartWidget({
    Key? key,
    required this.muscleGroupCounts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    if (muscleGroupCounts.isEmpty || muscleGroupCounts.values.every((count) => count == 0)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radar,
              size: 48,
              color: theme.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No muscle data available',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return _buildRadarChart(theme);
  }

  Widget _buildRadarChart(dynamic theme) {
    // Hitta maxvärdet för skalning
    final maxValue = muscleGroupCounts.values.reduce((a, b) => a > b ? a : b).toDouble();
    
    // Ordna muskelgrupperna i en logisk ordning för radar chart
    final orderedMuscleGroups = [
      'Chest',
      'Shoulders', 
      'Back',
      'Biceps',
      'Triceps',
      'Quads',
      'Hamstrings',
      'Glutes',
      'Abs',
    ];

    // Skapa data punkter för radar chart
    final radarDataSets = <RadarDataSet>[
      RadarDataSet(
        fillColor: theme.primary.withOpacity(0.2),
        borderColor: theme.primary,
        borderWidth: 3,
        entryRadius: 4,
        dataEntries: orderedMuscleGroups.map((muscleGroup) {
          final count = muscleGroupCounts[muscleGroup] ?? 0;
          // Normalisera värdet till 0-1 skala
          final normalizedValue = maxValue > 0 ? count / maxValue : 0.0;
          return RadarEntry(value: normalizedValue * 100); // Skala till 0-100
        }).toList(),
      ),
    ];

    return RadarChart(
      RadarChartData(
        dataSets: radarDataSets,
        radarBackgroundColor: Colors.transparent,
        borderData: FlBorderData(show: false),
        radarBorderData: const BorderSide(color: Colors.transparent),
        titlePositionPercentageOffset: 0.15,
        titleTextStyle: TextStyle(
          color: theme.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        getTitle: (index, angle) {
          if (index < orderedMuscleGroups.length) {
            final muscleGroup = orderedMuscleGroups[index];
            final count = muscleGroupCounts[muscleGroup] ?? 0;
            return RadarChartTitle(
              text: '$muscleGroup\n$count sets',
              angle: angle,
            );
          }
          return const RadarChartTitle(text: '');
        },
        tickCount: 4,
        ticksTextStyle: TextStyle(
          color: theme.textSecondary,
          fontSize: 10,
        ),
        tickBorderData: BorderSide(
          color: theme.textSecondary.withOpacity(0.3),
          width: 1,
        ),
        gridBorderData: BorderSide(
          color: theme.textSecondary.withOpacity(0.3),
          width: 1,
        ),
      ),
    );
  }
}