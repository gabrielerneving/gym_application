import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'create_workout.dart';
import 'workout_history.dart';
import 'statistics_screen.dart';
import 'active_workout_screen.dart';
import '../providers/workout_provider.dart';


class MainScreen extends ConsumerStatefulWidget {
  final int initialTabIndex; 
  const MainScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _animationController;
  late AnimationController _iconAnimationController;

  late final List<Widget> _widgetOptions; 

  final List<IconData> _icons = [
    Icons.home_outlined,           // Home
    Icons.add_outlined,            // Create Workout
    Icons.history_outlined,        // Workout History
    Icons.bar_chart_outlined,      // Statistics
  ];
  final List<IconData> _activeIcons = [
    Icons.home,                    // Home
    Icons.add,                     // Create Workout
    Icons.history,                 // Workout History
    Icons.bar_chart,               // Statistics
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      ref.read(workoutProvider.notifier).loadInitialState();
    });
    _selectedIndex = widget.initialTabIndex;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _widgetOptions = <Widget>[
    HomeScreen(
      onSwitchToProfileTab: () {  // Här definierar du vad som ska hända
        _onItemTapped(3); // Anropa din befintliga metod för att byta flik till index 3 (Profile)
      },
    ),
      CreateWorkoutScreen(
        onWorkoutSaved: (indexToGoTo) {
          setState(() {
            _selectedIndex = indexToGoTo;
          });
        },
      ),
      const WorkoutHistoryScreen(),
      const StatisticsScreen(),
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    
    setState(() {
      _selectedIndex = index;
    });
    
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    _iconAnimationController.forward().then((_) {
      _iconAnimationController.reverse();
    });
  }

Widget build(BuildContext context) {
  // Läs av workoutProvider som förut
  final activeWorkout = ref.watch(workoutProvider);

  final double navBarWidth = MediaQuery.of(context).size.width - 32;
  final double itemWidth = navBarWidth / _icons.length;

  return Scaffold(
    extendBody: true,
    backgroundColor: const Color(0xFF1B1C20),
    
    body: Stack(
      children: [
        // LAGER 1: Huvudinnehållet (din IndexedStack)
        // Detta lager ligger i botten och fyller hela skärmen under AppBar.
        IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions,
        ),

        // LAGER 2: Din "Workout in progress"-banner
        // Detta lager ligger OVANPÅ IndexedStack.
        // Vi använder en Positioned-widget för att placera den högst upp.
        if (activeWorkout.isRunning)
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: SafeArea( // SafeArea skyddar bara detta lager
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const ActiveWorkoutScreen(),
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        const Text(
                          'Workout in progress',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Text(
                          'Resume',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
      bottomNavigationBar: Container(
        height: 65,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 1)
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              left: _selectedIndex * itemWidth + (itemWidth / 2 - 35),
              top: 10,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_animationController.value * 0.1),
                    child: Container(
                      width: 70,
                      height: 45,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFDC2626),
                            Color.fromARGB(255, 250, 47, 47),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 224, 0, 0).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_icons.length, (index) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onItemTapped(index),
                    behavior: HitTestBehavior.translucent,
                    child: SizedBox(
                      height: 65,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _iconAnimationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _selectedIndex == index 
                                  ? 1.0 + (_iconAnimationController.value * 0.15)
                                  : 1.0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(8),
                              child: Icon(
                                  _selectedIndex == index ? _activeIcons[index] : _icons[index],
                                  color: _selectedIndex == index
                                      ? Colors.white
                                      : Colors.grey[500],
                                  size: _selectedIndex == index 
                                      ? (index == 1 ? 32 : 26)  // Plus-ikonen blir 32px när aktiv
                                      : (index == 1 ? 28 : 24), // Plus-ikonen blir 28px när inaktiv
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}