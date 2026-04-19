import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/popular_workouts_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/gradient_text.dart';
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import 'progression_screen.dart';
import 'muscle_groups_screen.dart';
import 'one_rm_screen.dart';
import 'settings_screen.dart';
import 'consistency_screen.dart';
import 'volume_tracker_screen.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  DatabaseService? _dbService;

  // Statistik data från databasen
  int workoutsThisMonth = 0;
  int totalWorkouts = 0;
  double totalHours = 0.0;
  double averageWorkoutDuration = 0.0;
  Map<String, int> popularWorkoutsData = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadStats();
  }

  Future<void> _initializeAndLoadStats() async {
    // Hämta uid från Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _dbService = DatabaseService(uid: user.uid);
      await _loadStatistics();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    if (_dbService == null) return;

    try {
      // Hämta ALL data EN gång istället för att anropa getAllWorkoutSessions() flera gånger
      final allSessions = await _dbService!.getAllWorkoutSessions();
      final workoutsThisMonthCount = await _dbService!.getWorkoutsThisMonth();

      // Beräkna total träningstid
      final totalMinutes = allSessions.fold<int>(
        0, (sum, session) => sum + session.durationInMinutes,
      );
      final hours = totalMinutes / 60.0;
      final avgDuration = allSessions.isEmpty ? 0.0 : totalMinutes / allSessions.length;

      // Beräkna mest tränade program
      final programCounts = <String, int>{};
      for (final session in allSessions) {
        programCounts[session.programTitle] = 
            (programCounts[session.programTitle] ?? 0) + 1;
      }
      final sortedEntries = programCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5 = Map<String, int>.fromEntries(sortedEntries.take(5));

      if (mounted) {
        setState(() {
          workoutsThisMonth = workoutsThisMonthCount;
          totalWorkouts = allSessions.length;
          totalHours = hours;
          averageWorkoutDuration = avgDuration;
          popularWorkoutsData = top5;
          isLoading = false;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Could not load statistics. Pull down to try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final themeIndex = ref.watch(themeIndexProvider);

    return Scaffold(
      backgroundColor: theme.background,
      body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GradientText(
                      text: 'Statistics',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                      ),
                      currentThemeIndex: themeIndex,
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: theme.text),
                      tooltip: 'Settings',
                      iconSize: 28,
                      padding: const EdgeInsets.all(12),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Expanded(
                  child:
                      isLoading
                          ? Center(
                            child: CircularProgressIndicator(
                              color: theme.primary,
                            ),
                          )
                          : RefreshIndicator(
                            color: theme.primary,
                            backgroundColor: theme.card,
                            onRefresh: () async {
                              await _loadStatistics();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Statistics refreshed',
                                      style: TextStyle(color: theme.text),
                                    ),
                                    backgroundColor: theme.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  // 2x2 statistik-kort
                                  GridView.count(
                                    crossAxisCount: 2,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.1,
                                    children: [
                                      StatCard(
                                        title: 'This month',
                                        value: workoutsThisMonth.toString(),
                                        unit: 'Workouts',
                                        icon: Icons.calendar_today,
                                        isPrimary: true,
                                      ),
                                      StatCard(
                                        title: 'Total workouts',
                                        value: totalWorkouts.toString(),
                                        unit: 'Sessions',
                                        icon: Icons.trending_up,
                                      ),
                                      StatCard(
                                        title: 'Total time',
                                        value: totalHours.toStringAsFixed(1),
                                        unit: 'Hours',
                                        icon: Icons.timer_outlined,
                                      ),
                                      StatCard(
                                        title: 'Average workout',
                                        value: averageWorkoutDuration
                                            .toStringAsFixed(0),
                                        unit: 'Minutes',
                                        icon: Icons.bar_chart,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildConsistencyButton(theme),
                                  const SizedBox(height: 16),
                                  _buildProgressionButton(theme),
                                  const SizedBox(height: 16),
                                  _buildOneRMButton(theme),
                                  const SizedBox(height: 16),
                                  _buildMuscleGroupsButton(theme),
                                  const SizedBox(height: 16),
                                  _buildVolumeTrackerButton(theme),
                                  const SizedBox(height: 24),
                                  PopularWorkoutsCard(
                                    popularWorkouts: popularWorkoutsData,
                                  ),
                                  // Extra utrymme så att "Most popular workouts" inte täcks av den flytande navbaren
                                  const SizedBox(height: 100),
                                ],
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildProgressionButton(theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProgressionScreen()),
        );
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.show_chart,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise Progression',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View weight progression charts',
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: theme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOneRMButton(theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OneRMScreen()),
        );
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.trending_up,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1RM Tracker',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track your estimated one-rep max',
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: theme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupsButton(theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MuscleGroupsScreen()),
        );
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.radar, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Muscle Groups',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyze muscle group distribution',
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: theme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeTrackerButton(theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VolumeTrackerScreen()),
        );
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Volume Tracker',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Working sets per muscle group',
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: theme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildConsistencyButton(theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ConsistencyScreen()),
        );
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consistency',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View your workout heatmap',
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: theme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
