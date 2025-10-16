import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';

class ProgressionChartWidget extends ConsumerStatefulWidget {
  final String exerciseName;
  final DatabaseService dbService;

  const ProgressionChartWidget({
    Key? key,
    required this.exerciseName,
    required this.dbService,
  }) : super(key: key);

  @override
  _ProgressionChartWidgetState createState() => _ProgressionChartWidgetState();
}

class _ProgressionChartWidgetState extends ConsumerState<ProgressionChartWidget> {
  List<ProgressionDataPoint> progressionData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressionData();
  }

  @override
  void didUpdateWidget(ProgressionChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseName != widget.exerciseName) {
      _loadProgressionData();
    }
  }

  Future<void> _loadProgressionData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await widget.dbService.getExerciseProgression(widget.exerciseName);
      if (mounted) {
        setState(() {
          progressionData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading progression data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.primary,
        ),
      );
    }

    if (progressionData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: theme.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No data for this exercise',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return _buildChart(theme);
  }

  Widget _buildChart(dynamic theme) {
    // Kontrollera om vi har data
    if (progressionData.isEmpty) {
      return const Center(
        child: Text(
          'No progression data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Skapa två sets av punkter - en för max vikt och en för max volym
    final weightSpots = progressionData.asMap().entries.map((entry) {
      final index = entry.key;
      final dataPoint = entry.value;
      return FlSpot(index.toDouble(), dataPoint.maxWeight);
    }).toList();
    
    final volumeSpots = progressionData.asMap().entries.map((entry) {
      final index = entry.key;
      final dataPoint = entry.value;
      return FlSpot(index.toDouble(), dataPoint.maxVolume);
    }).toList();

    // Hitta min och max värden för y-axeln (behöver täcka både vikt och volym)
    final weights = progressionData.map((p) => p.maxWeight).toList();
    final volumes = progressionData.map((p) => p.maxVolume).toList();
    
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final minVolume = volumes.reduce((a, b) => a < b ? a : b);
    final maxVolume = volumes.reduce((a, b) => a > b ? a : b);
    
    // Använd den största skalan för att båda linjerna syns bra
    final minValue = minWeight < minVolume ? minWeight : minVolume;
    final maxValue = maxWeight > maxVolume ? maxWeight : maxVolume;
    
    // Lägg till lite marginal
    final valueRange = maxValue - minValue;
    final margin = valueRange > 0 ? valueRange * 0.1 : (maxValue > 0 ? maxValue * 0.1 : 1.0);
    final yMin = (minValue - margin).clamp(0.0, double.infinity);
    final yMax = maxValue + margin;
    
    // Säkerställ att horizontalInterval aldrig är 0
    final yRange = yMax - yMin;
    final horizontalInterval = yRange > 0 ? yRange / 4 : 1.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.textSecondary.withOpacity(0.3),
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
              reservedSize: 30,
              interval: progressionData.length > 6 ? (progressionData.length / 4).ceilToDouble() : 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < progressionData.length) {
                  final date = progressionData[index].date;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
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
              interval: (yMax - yMin) / 4,
              reservedSize: 45,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  '${value.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        minX: 0,
        maxX: (progressionData.length - 1).toDouble(),
        minY: yMin,
        maxY: yMax,
        lineBarsData: [
          // Linje för max vikt
          LineChartBarData(
            spots: weightSpots,
            gradient: LinearGradient(
              colors: [
                theme.primary,
                theme.primaryLight,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: theme.primary,
                  strokeWidth: 2,
                  strokeColor: theme.background,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
          // Linje för max volym
          LineChartBarData(
            spots: volumeSpots,
            gradient: LinearGradient(
              colors: [
                theme.accent,
                theme.accent.withOpacity(0.7),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: theme.accent,
                  strokeWidth: 2,
                  strokeColor: theme.background,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  theme.accent.withOpacity(0.1),
                  theme.accent.withOpacity(0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => theme.card,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                if (index >= 0 && index < progressionData.length) {
                  final dataPoint = progressionData[index];
                  final isWeightLine = barSpot.barIndex == 0;
                  
                  if (isWeightLine) {
                    return LineTooltipItem(
                      'Max Weight: ${dataPoint.maxWeight.toStringAsFixed(1)}kg × ${dataPoint.maxWeightReps}\n${_formatDate(dataPoint.date)}',
                      TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    );
                  } else {
                    return LineTooltipItem(
                      'Max Volume: ${dataPoint.maxVolume.toStringAsFixed(0)}\n(${dataPoint.maxVolumeWeight.toStringAsFixed(1)}kg × ${dataPoint.maxVolumeReps})\n${_formatDate(dataPoint.date)}',
                      TextStyle(
                        color: theme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    );
                  }
                }
                return null;
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((spotIndex) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: theme.primary.withOpacity(0.5),
                  strokeWidth: 2,
                ),
                FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: theme.primary,
                      strokeWidth: 2,
                      strokeColor: theme.background,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}