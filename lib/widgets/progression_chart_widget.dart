import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';

class ProgressionChartWidget extends StatefulWidget {
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

class _ProgressionChartWidgetState extends State<ProgressionChartWidget> {
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
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFDC2626),
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
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 12),
            Text(
              'No data for this exercise',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return _buildChart();
  }

  Widget _buildChart() {
    // Skapa FlSpot-punkter från progressionData
    final spots = progressionData.asMap().entries.map((entry) {
      final index = entry.key;
      final dataPoint = entry.value;
      return FlSpot(index.toDouble(), dataPoint.weight);
    }).toList();

    // Hitta min och max värden för y-axeln
    final weights = progressionData.map((p) => p.weight).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    
    // Lägg till lite marginal
    final margin = (maxWeight - minWeight) * 0.1;
    final yMin = (minWeight - margin).clamp(0.0, double.infinity);
    final yMax = maxWeight + margin;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: (yMax - yMin) / 4,
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
                        color: Colors.grey.shade500,
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
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  '${value.toStringAsFixed(0)}kg',
                  style: TextStyle(
                    color: Colors.grey.shade500,
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
          LineChartBarData(
            spots: spots,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFDC2626),
                Color(0xFFEF4444),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFFDC2626),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFDC2626).withOpacity(0.1),
                  const Color(0xFFDC2626).withOpacity(0.02),
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
            getTooltipColor: (touchedSpot) => const Color(0xFF18181B),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                if (index >= 0 && index < progressionData.length) {
                  final dataPoint = progressionData[index];
                  return LineTooltipItem(
                    '${dataPoint.weight.toStringAsFixed(1)} kg\n${_formatDate(dataPoint.date)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
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
                  color: const Color(0xFFDC2626).withOpacity(0.5),
                  strokeWidth: 2,
                ),
                FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: const Color(0xFFDC2626),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
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