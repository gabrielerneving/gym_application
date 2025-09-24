import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/popular_workouts_card.dart';
import '../widgets/stat_card.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'progression_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedIndex = 3; // Index 3 är den aktiva "profil"-ikonen
  DatabaseService? _dbService;
  
  // Statistik data som vi laddar från databasen
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
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Huvudinnehåll
          Column(
            children: [
              // AppBar-området
              Container(
                height: 80,
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          'Statistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 34,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Log out',
                        onPressed: () async {
                          await AuthService().signOut();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollbart innehåll
              Expanded(
                child: isLoading 
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFDC2626),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 100),
                      child: Column(
                        children: [
                          // Grid med 2x2 statistik-kort
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

                          // Progression button
                          _buildProgressionButton(),
                          
                          const SizedBox(height: 24),

                          // Kort för populära workouts
                          PopularWorkoutsCard(popularWorkouts: popularWorkoutsData),
                        ],
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
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2)
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_outlined, 0),
                  _buildNavItem(Icons.fitness_center_outlined, 1),
                  _buildNavItem(Icons.history, 2),
                  _buildNavItem(Icons.bar_chart_outlined, 3), // Detta är den aktiva
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
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
          color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.shade600,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildProgressionButton() {
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
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2A2A2A),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
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
                  const Text(
                    'Exercise Progression',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View weight progression charts',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade600,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}