import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/stat_card.dart';

class ConsistencyScreen extends ConsumerStatefulWidget {
  const ConsistencyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsistencyScreen> createState() => _ConsistencyScreenState();
}

class _ConsistencyScreenState extends ConsumerState<ConsistencyScreen> {
  DatabaseService? _dbService;
  Map<DateTime, int> allHeatmapData = {}; // Store all data
  Map<DateTime, int> filteredHeatmapData = {}; // Store filtered data
  bool isLoading = true;
  
  // Time Range
  int? selectedRangeDays = 90; // Default to 3 months (90 days). Null means "All Time"
  
  // Stats
  double averagePerWeek = 0.0;
  double averagePerMonth = 0.0;
  int totalWorkouts = 0;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadStats();
  }

  Future<void> _initializeAndLoadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _dbService = DatabaseService(uid: user.uid);
      await _loadHeatmapData();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadHeatmapData() async {
    if (_dbService == null) return;

    try {
      final data = await _dbService!.getWorkoutHeatmapData();
      
      if (mounted) {
        setState(() {
          allHeatmapData = data;
          _filterDataAndCalculateStats();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading heatmap data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _filterDataAndCalculateStats() {
    final now = DateTime.now();
    DateTime startDate;
    
    if (selectedRangeDays != null) {
      startDate = now.subtract(Duration(days: selectedRangeDays!));
    } else {
      // For "All Time", find the earliest date in data or default to 1 year ago if empty
      if (allHeatmapData.isNotEmpty) {
        startDate = allHeatmapData.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      } else {
        startDate = now.subtract(const Duration(days: 365));
      }
    }
    
    // Filter data
    final Map<DateTime, int> filtered = {};
    allHeatmapData.forEach((date, count) {
      if (date.isAfter(startDate.subtract(const Duration(days: 1))) && date.isBefore(now.add(const Duration(days: 1)))) {
        filtered[date] = count;
      }
    });
    
    // Calculate stats based on filtered data
    double avgWeek = 0.0;
    double avgMonth = 0.0;
    int total = 0;
    
    if (filtered.isNotEmpty) {
      total = filtered.values.fold(0, (sum, count) => sum + count);
      
      // Calculate days in range (actual range or selected range)
      int daysInRange;
      if (selectedRangeDays != null) {
        daysInRange = selectedRangeDays!;
      } else {
         final firstDate = filtered.keys.reduce((a, b) => a.isBefore(b) ? a : b);
         daysInRange = now.difference(firstDate).inDays + 1;
      }
      
      if (daysInRange > 0) {
        final weeks = daysInRange / 7.0;
        final months = daysInRange / 30.44;
        
        avgWeek = weeks > 0 ? total / weeks : 0.0;
        avgMonth = months > 0 ? total / months : 0.0;
      }
    }

    setState(() {
      filteredHeatmapData = filtered;
      averagePerWeek = avgWeek;
      averagePerMonth = avgMonth;
      totalWorkouts = total;
    });
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
          'Consistency',
          style: TextStyle(
            color: theme.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _buildTimeRangeSelector(theme),
          const SizedBox(width: 16),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.textSecondary.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workout History',
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Visualize your training consistency over time.',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        HeatMap(
                          datasets: filteredHeatmapData,
                          colorMode: ColorMode.opacity,
                          showText: false,
                          scrollable: true,
                          colorsets: {
                            1: theme.primary,
                          },
                          onClick: (value) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${value.year}-${value.month}-${value.day}: ${filteredHeatmapData[value] ?? 0} workouts',
                                  style: TextStyle(color: theme.text),
                                ),
                                backgroundColor: theme.card,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          startDate: selectedRangeDays != null 
                              ? DateTime.now().subtract(Duration(days: selectedRangeDays!))
                              : (allHeatmapData.isNotEmpty 
                                  ? allHeatmapData.keys.reduce((a, b) => a.isBefore(b) ? a : b) 
                                  : DateTime.now().subtract(const Duration(days: 365))),
                          endDate: DateTime.now(),
                          size: 20,
                          textColor: theme.textSecondary,
                          fontSize: 12,
                          defaultColor: theme.background,
                          showColorTip: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      StatCard(
                        title: 'Average / Week',
                        value: averagePerWeek.toStringAsFixed(1),
                        unit: 'Workouts',
                        icon: Icons.calendar_view_week,
                        backgroundColor: theme.primary,
                      ),
                      StatCard(
                        title: 'Average / Month',
                        value: averagePerMonth.toStringAsFixed(1),
                        unit: 'Workouts',
                        icon: Icons.calendar_month,
                      ),
                      StatCard(
                        title: 'Total Workouts',
                        value: '$totalWorkouts',
                        unit: 'Sessions',
                        icon: Icons.fitness_center,
                      ),
                      StatCard(
                        title: 'Active Days',
                        value: '${filteredHeatmapData.length}',
                        unit: 'Days',
                        icon: Icons.calendar_today,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTimeRangeSelector(theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.textSecondary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedRangeDays,
          icon: Icon(Icons.arrow_drop_down, color: theme.primary),
          dropdownColor: theme.card,
          style: TextStyle(
            color: theme.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: [
            DropdownMenuItem(
              value: 90,
              child: Text('3 Months', style: TextStyle(color: theme.text)),
            ),
            DropdownMenuItem(
              value: 180,
              child: Text('6 Months', style: TextStyle(color: theme.text)),
            ),
            DropdownMenuItem(
              value: 365,
              child: Text('1 Year', style: TextStyle(color: theme.text)),
            ),
            DropdownMenuItem(
              value: null,
              child: Text('All Time', style: TextStyle(color: theme.text)),
            ),
          ],
          onChanged: (value) {
            setState(() {
              selectedRangeDays = value;
              _filterDataAndCalculateStats();
            });
          },
        ),
      ),
    );
  }
}
