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

class _MuscleGroupsScreenState extends State<MuscleGroupsScreen> {
  DatabaseService? _dbService;
  Map<String, int> muscleGroupCounts = {};
  Map<String, double> muscleGroupPercentages = {};
  List<MuscleGroupStat> mostTrainedMuscles = [];
  bool isLoading = true;
  int selectedChartType = 0; // 0 = radar, 1 = bar chart

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

    try {
      final results = await Future.wait([
        _dbService!.getMuscleGroupSetCounts(),
        _dbService!.getMuscleGroupPercentages(),
        _dbService!.getMostTrainedMuscleGroups(),
      ]);

      if (mounted) {
        setState(() {
          muscleGroupCounts = results[0] as Map<String, int>;
          muscleGroupPercentages = results[1] as Map<String, double>;
          mostTrainedMuscles = results[2] as List<MuscleGroupStat>;
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
            selectedChartType == 0 ? 'Muscle Distribution' : 'Sets per Muscle Group',
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