import 'package:flutter/material.dart';
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

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _selectedIndex = 3; // Index 3 är den aktiva "profil"-ikonen
  DatabaseService? _dbService;
  
  // Statistik data från databasen
  int workoutsThisMonth = 0;
  int totalWorkouts = 0;
  double totalHours = 0.0;
  double averageWorkoutDuration = 0.0;
  Map<String, int> popularWorkoutsData = {};
  bool isLoading = true;

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
      final results = await Future.wait([
        _dbService!.getWorkoutsThisMonth(),
        _dbService!.getTotalWorkouts(),
        _dbService!.getTotalTrainingHours(),
        _dbService!.getAverageWorkoutDuration(),
        _dbService!.getMostTrainedPrograms(),
      ]);

      if (mounted) {
        setState(() {
          workoutsThisMonth = results[0] as int;
          totalWorkouts = results[1] as int;
          totalHours = results[2] as double;
          averageWorkoutDuration = results[3] as double;
          popularWorkoutsData = results[4] as Map<String, int>;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
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
    final themeIndex = ref.watch(themeIndexProvider);
    
    return Scaffold(
      extendBody: true,
      backgroundColor: theme.background,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 80,
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: GradientText(
                          text: 'Statistics',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 34,
                          ),
                          currentThemeIndex: themeIndex,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 4),
                      child: IconButton(
                        icon: Icon(Icons.settings, color: theme.text),
                        tooltip: 'Settings',
                        iconSize: 28,
                        padding: const EdgeInsets.all(12),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading 
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
                              content: Text('Statistics refreshed', style: TextStyle(color: theme.text),),
                              backgroundColor: theme.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 100),
                        child: Column(
                        children: [
                          // 2x2 statistik-kort
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: [
                              StatCard(
                                title: 'This month',
                                value: workoutsThisMonth.toString(),
                                unit: 'Workouts',
                                icon: Icons.calendar_today,
                                backgroundColor: const Color(0xFFDC2626),
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
                                value: averageWorkoutDuration.toStringAsFixed(0),
                                unit: 'Minutes',
                                icon: Icons.bar_chart,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildProgressionButton(theme),
                          const SizedBox(height: 16),
                          _buildOneRMButton(theme),
                          const SizedBox(height: 16),
                          _buildMuscleGroupsButton(theme),
                          const SizedBox(height: 24),
                          PopularWorkoutsCard(popularWorkouts: popularWorkoutsData),
                        ],
                        ),
                      ),
                    ),
              ),
            ],
          ),          // Flytande navbar
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              height: 65,
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  // Huvudskugga - mjukare och mindre aggressiv
                  BoxShadow(
                    color: theme.primary.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  // Liten skugga nära navbaren
                  BoxShadow(
                    color: theme.primary.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: -1,
                  ),
                ],
                border: Border.all(
                  color: theme.textSecondary.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_outlined, 0, theme),
                  _buildNavItem(Icons.fitness_center_outlined, 1, theme),
                  _buildNavItem(Icons.history, 2, theme),
                  _buildNavItem(Icons.bar_chart_outlined, 3, theme), // Aktiv ikon
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, theme) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : theme.textSecondary,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildProgressionButton(theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProgressionScreen(),
          ),
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
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOneRMButton(theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OneRMScreen(),
          ),
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
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupsButton(theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MuscleGroupsScreen(),
          ),
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
                Icons.radar,
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
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}