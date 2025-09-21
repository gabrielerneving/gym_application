import 'package:flutter/material.dart';
import '../widgets/popular_workouts_card.dart';
import '../widgets/stat_card.dart';
import '../services/auth_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedIndex = 3; // Index 3 är den aktiva "profil"-ikonen

  @override
  Widget build(BuildContext context) {
    // I en riktig app skulle denna data komma från en databas eller state management.
    // Här simulerar vi datan.
    final int workoutsThisMonth = 5;
    final int totalHours = 5;
    final Map<String, int> popularWorkoutsData = {
      'Upper 1': 2,
      'Upper 2': 3,
    };

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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 100), // Extra bottom padding för navbar
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
                            title: 'Total',
                            value: totalHours.toString(),
                            unit: 'Hours',
                            icon: Icons.trending_up,
                          ),
                          StatCard(
                            title: 'Total time',
                            value: totalHours.toString(),
                            unit: 'Hours',
                            icon: Icons.timer_outlined,
                          ),
                          StatCard(
                            title: 'Average workout',
                            value: '5',
                            unit: 'Hours',
                            icon: Icons.bar_chart,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Kort för populära workouts
                      PopularWorkoutsCard(popularWorkouts: popularWorkoutsData),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Flytande navbar
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
}