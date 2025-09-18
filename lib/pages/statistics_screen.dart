import 'package:flutter/material.dart';
import '../widgets/popular_workouts_card.dart';
import '../widgets/stat_card.dart';

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Text(
          'Statistics',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 34,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Grid med 2x2 statistik-kort
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1, // Justera för att få rätt höjd
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
                  value: '5', // Hårdkodat värde enligt design
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
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  // Klistra in samma botten-meny-kod som från förra skärmen
  Widget _buildCustomBottomNav() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_outlined, 0),
          _buildNavItem(Icons.fitness_center_outlined, 1),
          _buildNavItem(Icons.person_outline, 2),
          _buildNavItem(Icons.settings_outlined, 3), // Denna är aktiv
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