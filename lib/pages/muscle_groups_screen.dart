import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../widgets/muscle_radar_chart_widget.dart';
import '../widgets/muscle_bar_chart_widget.dart';

class MuscleGroupsScreen extends StatefulWidget {
  const MuscleGroupsScreen({Key? key}) : super(key: key);

  @override
  _MuscleGroupsScreenState createState() => _MuscleGroupsScreenState();
}

enum TimePeriod { thisMonth, lastThreeMonths, allTime }

class _MuscleGroupsScreenState extends State<MuscleGroupsScreen> {
  DatabaseService? _dbService;
  Map<String, int> muscleGroupCounts = {};
  Map<String, double> muscleGroupPercentages = {};
  List<MuscleGroupStat> mostTrainedMuscles = [];
  bool isLoading = true;
  int selectedChartType = 0; // 0 = radar, 1 = bar chart
  TimePeriod selectedPeriod = TimePeriod.allTime;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _dbService = DatabaseService(uid: user.uid);
      await _loadMuscleData();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMuscleData() async {
    if (_dbService == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Beräkna datum baserat på vald period
      final now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate = now;

      switch (selectedPeriod) {
        case TimePeriod.thisMonth:
          startDate = DateTime(now.year, now.month, 1);
          break;
        case TimePeriod.lastThreeMonths:
          startDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case TimePeriod.allTime:
          startDate = null;
          endDate = null;
          break;
      }

      // Använd period-specifika metoder
      final Map<String, int> counts;
      if (startDate != null && endDate != null) {
        counts = await _dbService!.getMuscleGroupSetCountsInPeriod(
          startDate: startDate,
          endDate: endDate,
        );
      } else {
        counts = await _dbService!.getMuscleGroupSetCounts();
      }

      // Beräkna procent och mest tränade muskler
      final totalSets = counts.values.fold<int>(0, (sum, count) => sum + count);
      final percentages = <String, double>{};
      final stats = <MuscleGroupStat>[];

      for (final entry in counts.entries) {
        if (totalSets > 0) {
          percentages[entry.key] = (entry.value / totalSets) * 100;
        }
        stats.add(MuscleGroupStat(
          muscleGroup: entry.key,
          setCount: entry.value,
        ));
      }

      // Sortera stats
      stats.sort((a, b) => b.setCount.compareTo(a.setCount));

      if (mounted) {
        setState(() {
          muscleGroupCounts = counts;
          muscleGroupPercentages = percentages;
          mostTrainedMuscles = stats;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading muscle data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _onPeriodChanged(TimePeriod newPeriod) {
    if (selectedPeriod != newPeriod) {
      setState(() {
        selectedPeriod = newPeriod;
      });
      _loadMuscleData();
    }
  }

  String _getChartTitle() {
    final chartType = selectedChartType == 0 ? 'Muscle Distribution' : 'Sets per Muscle Group';
    final period = _getPeriodText();
    return '$chartType - $period';
  }

  String _getPeriodText() {
    switch (selectedPeriod) {
      case TimePeriod.thisMonth:
        return 'Denna månad';
      case TimePeriod.lastThreeMonths:
        return 'Senaste 3 månader';
      case TimePeriod.allTime:
        return 'All tid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFFDC2626).withOpacity(0.8), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Muscle Groups',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          // Toggle mellan radar och bar chart
          IconButton(
            icon: Icon(
              selectedChartType == 0 ? Icons.bar_chart : Icons.radar,
              color: const Color(0xFFDC2626),
            ),
            onPressed: () {
              setState(() {
                selectedChartType = selectedChartType == 0 ? 1 : 0;
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
          : muscleGroupCounts.isEmpty || muscleGroupCounts.values.every((count) => count == 0)
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time period selector
                      _buildTimePeriodSelector(),
                      const SizedBox(height: 16),

                      // Chart type selector
                      _buildChartTypeSelector(),
                      const SizedBox(height: 24),

                      // Main chart
                      _buildMainChart(),
                      const SizedBox(height: 24),

                      // Top muscle groups list
                      _buildTopMuscleGroupsList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No muscle data yet',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some workouts to see your muscle group distribution',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(TimePeriod.thisMonth),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedPeriod == TimePeriod.thisMonth ? const Color(0xFFDC2626) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Denna månad',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selectedPeriod == TimePeriod.thisMonth ? Colors.white : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(TimePeriod.lastThreeMonths),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedPeriod == TimePeriod.lastThreeMonths ? const Color(0xFFDC2626) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Senaste 3 mån',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selectedPeriod == TimePeriod.lastThreeMonths ? Colors.white : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(TimePeriod.allTime),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedPeriod == TimePeriod.allTime ? const Color(0xFFDC2626) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'All tid',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selectedPeriod == TimePeriod.allTime ? Colors.white : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedChartType = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedChartType == 0 ? const Color(0xFFDC2626) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.radar,
                      color: selectedChartType == 0 ? Colors.white : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Radar Chart',
                      style: TextStyle(
                        color: selectedChartType == 0 ? Colors.white : Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedChartType = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selectedChartType == 1 ? const Color(0xFFDC2626) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart,
                      color: selectedChartType == 1 ? Colors.white : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bar Chart',
                      style: TextStyle(
                        color: selectedChartType == 1 ? Colors.white : Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade800.withOpacity(0.6),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getChartTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: selectedChartType == 0
                ? MuscleRadarChartWidget(
                    muscleGroupCounts: muscleGroupCounts,
                  )
                : MuscleBarChartWidget(
                    muscleGroupCounts: muscleGroupCounts,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMuscleGroupsList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most Trained Muscles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...mostTrainedMuscles.take(5).map((stat) => _buildMuscleStatRow(stat)),
        ],
      ),
    );
  }

  Widget _buildMuscleStatRow(MuscleGroupStat stat) {
    final percentage = muscleGroupPercentages[stat.muscleGroup] ?? 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getMuscleColor(stat.muscleGroup),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                stat.muscleGroup.substring(0, 1).toUpperCase(),
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
                Text(
                  stat.muscleGroup,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${stat.setCount} sets (${percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _getMuscleColor(stat.muscleGroup),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMuscleColor(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest': return const Color(0xFFDC2626);
      case 'Back': return const Color(0xFF16A34A);
      case 'Shoulders': return const Color(0xFF2563EB);
      case 'Biceps': return const Color(0xFF7C3AED);
      case 'Triceps': return const Color(0xFFEAB308);
      case 'Legs': return const Color(0xFFE11D48);
      case 'Abs': return const Color(0xFF06B6D4);
      default: return Colors.grey;
    }
  }
}