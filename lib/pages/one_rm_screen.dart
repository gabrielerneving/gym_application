import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/one_rm_calculator.dart';
import 'package:fl_chart/fl_chart.dart';

class OneRMScreen extends ConsumerStatefulWidget {
  const OneRMScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OneRMScreen> createState() => _OneRMScreenState();
}

class _OneRMScreenState extends ConsumerState<OneRMScreen> {
  DatabaseService? _dbService;
  List<String> exerciseNames = [];
  String? selectedExercise;
  OneRMFormula selectedFormula = OneRMFormula.epley;
  List<OneRMDataPoint> oneRMData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _dbService = DatabaseService(uid: user.uid);
      await _loadExerciseNames();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadExerciseNames() async {
    if (_dbService == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final names = await _dbService!.getAllExerciseNames();
      if (mounted) {
        setState(() {
          exerciseNames = names;
          if (names.isNotEmpty && selectedExercise == null) {
            selectedExercise = names.first;
            _loadOneRMData();
          } else {
            isLoading = false;
          }
        });
      }
    } catch (e) {
      print('Error loading exercise names: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadOneRMData() async {
    if (_dbService == null || selectedExercise == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await _dbService!.getOneRMProgression(
        selectedExercise!,
        formula: selectedFormula,
      );
      if (mounted) {
        setState(() {
          oneRMData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading 1RM data: $e');
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
    
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primary.withOpacity(0.8), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '1RM Tracker',
          style: TextStyle(
            color: theme.text,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
              ),
            )
          : exerciseNames.isEmpty
              ? _buildEmptyState(theme)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildExerciseSelector(theme),
                      const SizedBox(height: 16),
                      _buildFormulaSelector(theme),
                      const SizedBox(height: 24),
                      if (oneRMData.isNotEmpty) ...[
                        _buildCurrentOneRM(theme),
                        const SizedBox(height: 24),
                        _buildOneRMChart(theme),
                        const SizedBox(height: 24),
                        _buildPercentageGuide(theme),
                      ] else
                        _buildNoDataForExercise(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppColors theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 80,
            color: theme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No workouts yet',
            style: TextStyle(
              color: theme.text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some workouts to see your 1RM',
            style: TextStyle(
              color: theme.text.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataForExercise(AppColors theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 60,
              color: theme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No data for this exercise',
              style: TextStyle(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete some sets to calculate your 1RM',
              style: TextStyle(
                color: theme.text.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSelector(AppColors theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedExercise,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: theme.primary),
          style: TextStyle(
            color: theme.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: theme.surface,
          items: exerciseNames.map((String exercise) {
            return DropdownMenuItem<String>(
              value: exercise,
              child: Text(exercise),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                selectedExercise = newValue;
              });
              _loadOneRMData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildFormulaSelector(AppColors theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OneRMFormula>(
          value: selectedFormula,
          isExpanded: true,
          icon: Icon(Icons.calculate, color: theme.primary),
          style: TextStyle(
            color: theme.text,
            fontSize: 14,
          ),
          dropdownColor: theme.surface,
          items: OneRMFormula.values.map((OneRMFormula formula) {
            return DropdownMenuItem<OneRMFormula>(
              value: formula,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formula.displayName,
                    style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formula.description,
                    style: TextStyle(
                      color: theme.text.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (OneRMFormula? newValue) {
            if (newValue != null) {
              setState(() {
                selectedFormula = newValue;
              });
              _loadOneRMData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildCurrentOneRM(AppColors theme) {
    final current = oneRMData.last;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primary.withOpacity(0.2), theme.primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Estimated 1RM',
            style: TextStyle(
              color: theme.text.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${current.oneRM.toStringAsFixed(1)} kg',
            style: TextStyle(
              color: theme.primary,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on ${current.weight.toStringAsFixed(1)}kg × ${current.reps} reps',
            style: TextStyle(
              color: theme.text.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          if (oneRMData.length > 1) ...[
            const SizedBox(height: 12),
            _buildProgressIndicator(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(AppColors theme) {
    final current = oneRMData.last.oneRM;
    final previous = oneRMData[oneRMData.length - 2].oneRM;
    final difference = current - previous;
    final percentChange = (difference / previous) * 100;
    
    final isPositive = difference > 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '${isPositive ? '+' : ''}${difference.toStringAsFixed(1)} kg (${percentChange.toStringAsFixed(1)}%)',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOneRMChart(AppColors theme) {
    if (oneRMData.isEmpty) return const SizedBox();

    final spots = oneRMData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.oneRM);
    }).toList();

    final oneRMs = oneRMData.map((p) => p.oneRM).toList();
    final minY = oneRMs.reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = oneRMs.reduce((a, b) => a > b ? a : b) * 1.05;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1RM Progression',
            style: TextStyle(
              color: theme.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.text.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}kg',
                          style: TextStyle(
                            color: theme.text.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < oneRMData.length) {
                          final date = oneRMData[value.toInt()].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.month}/${date.day}',
                              style: TextStyle(
                                color: theme.text.withOpacity(0.6),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: theme.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: theme.primary,
                          strokeWidth: 2,
                          strokeColor: theme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.primary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageGuide(AppColors theme) {
    if (oneRMData.isEmpty) return const SizedBox();
    
    final oneRM = oneRMData.last.oneRM;
    final percentages = [
      {'percent': 95, 'reps': '1-2', 'label': 'Strength', 'color': Colors.red},
      {'percent': 85, 'reps': '3-5', 'label': 'Power', 'color': Colors.orange},
      {'percent': 75, 'reps': '6-8', 'label': 'Hypertrophy', 'color': Colors.blue},
      {'percent': 65, 'reps': '9-12', 'label': 'Endurance', 'color': Colors.green},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Training Zones',
            style: TextStyle(
              color: theme.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommended weights based on your 1RM',
            style: TextStyle(
              color: theme.text.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ...percentages.map((zone) {
            final percent = zone['percent'] as int;
            final weight = OneRMCalculator.percentageWeight(oneRM, percent.toDouble());
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: zone['color'] as Color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              zone['label'] as String,
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${weight.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$percent% × ${zone['reps']} reps',
                          style: TextStyle(
                            color: theme.text.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
