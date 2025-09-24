import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../widgets/progression_chart_widget.dart';

class ProgressionScreen extends StatefulWidget {
  const ProgressionScreen({Key? key}) : super(key: key);

  @override
  _ProgressionScreenState createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends State<ProgressionScreen> {
  DatabaseService? _dbService;
  List<String> exerciseNames = [];
  Map<String, PersonalRecord> personalRecords = {};
  String? selectedExercise;
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
      await _loadProgressionData();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadProgressionData() async {
    if (_dbService == null) return;

    try {
      final results = await Future.wait([
        _dbService!.getAllExerciseNames(),
        _dbService!.getAllPersonalRecords(),
      ]);

      if (mounted) {
        setState(() {
          exerciseNames = results[0] as List<String>;
          personalRecords = results[1] as Map<String, PersonalRecord>;
          // Välj första övningen som default
          if (exerciseNames.isNotEmpty) {
            selectedExercise = exerciseNames.first;
          }
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
          'Progression',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFDC2626),
              ),
            )
          : exerciseNames.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exercise selector
                      _buildExerciseSelector(),
                      const SizedBox(height: 24),

                      // Personal record card
                      if (selectedExercise != null && personalRecords.containsKey(selectedExercise))
                        _buildPersonalRecordCard(),

                      const SizedBox(height: 24),

                      // Progression chart
                      if (selectedExercise != null)
                        _buildProgressionChart(),
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
            Icons.show_chart,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No workout data yet',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some workouts to see your progression',
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

  Widget _buildExerciseSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(
            'Select Exercise',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedExercise,
              isExpanded: true,
              dropdownColor: const Color(0xFF18181B),
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
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
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalRecordCard() {
    final record = personalRecords[selectedExercise!]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Personal Record',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${record.weight.toStringAsFixed(1)} kg',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Set on ${_formatDate(record.date)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
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
            'Weight Progression',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ProgressionChartWidget(
              exerciseName: selectedExercise!,
              dbService: _dbService!,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}