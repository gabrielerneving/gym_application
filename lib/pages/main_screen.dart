import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'create_workout.dart';
import 'workout_history.dart';
import 'statistics_screen.dart';
import 'active_workout_screen.dart';
import '../providers/workout_provider.dart';
import '../providers/theme_provider.dart';


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
      duration: const Duration(milliseconds: 2000), // Längre duration för mjuk pulsning
      vsync: this,
    );
    
    // Starta kontinuerlig pulsning för workout banner
    _animationController.repeat(reverse: true);
    
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _widgetOptions = <Widget>[
    HomeScreen(
      onSwitchToProfileTab: () {  
        _onItemTapped(3); 
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
  final activeWorkout = ref.watch(workoutProvider);

  // Sätt status bar stil
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  final double navBarWidth = MediaQuery.of(context).size.width - 32;
  final double itemWidth = navBarWidth / _icons.length;

  final theme = ref.watch(themeProvider);
  
  return Scaffold(
    extendBody: true,
    extendBodyBehindAppBar: true,
    backgroundColor: theme.background,
    
    body: Stack(
      children: [
        // LAGER 1: Huvudinnehållet med dynamisk padding för bannern
        AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.only(
            top: activeWorkout.isRunning ? 80 : 0, // 80px space för bannern när den visas
          ),
          child: IndexedStack(
            index: _selectedIndex,
            children: _widgetOptions,
          ),
        ),

        // LAGER 2: Förbättrad "Workout in progress"-banner
        if (activeWorkout.isRunning)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final statusBarHeight = MediaQuery.of(context).padding.top;
                return Container(
                  // Täcker hela övre området inklusive status bar
                  padding: EdgeInsets.only(
                    top: statusBarHeight + 8,
                    left: 12,
                    right: 12,
                  ),
                  decoration: BoxDecoration(
                    // Gradient som täcker hela övre området
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color.fromARGB(255, 0, 0, 0), // Samma som scaffold bakgrund
                        const Color.fromARGB(255, 0, 0, 0).withOpacity(0.9),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.7, 1.0],
                    ),
                  ),
                  child: Transform.scale(
                    scale: 1.0 + (_animationController.value * 0.02),
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        // Enklare svart design med subtle röd accent
                        color: Colors.black.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withOpacity(0.2 + (_animationController.value * 0.1)),
                            blurRadius: 10 + (_animationController.value * 3),
                            offset: const Offset(0, 2),
                            spreadRadius: 0.5,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFDC2626).withOpacity(0.3 + (_animationController.value * 0.2)),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const ActiveWorkoutScreen(),
                            ));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Row(
                              children: [
                                // Enklare pulsande ikon
                                AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 1.0 + (_animationController.value * 0.1),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626).withOpacity(0.2 + (_animationController.value * 0.1)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.fitness_center,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                // Text med fadeIn-effekt
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Workout Active',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          shadows: [
                                            Shadow(
                                              offset: const Offset(0, 1),
                                              blurRadius: 2,
                                              color: Colors.black.withOpacity(0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'Tap to continue',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Enklare animerad pil
                                AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(_animationController.value * 2, 0),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDC2626).withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // LAGER 3: Flytande navbar
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
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: theme.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2)
                ),
              ],
              border: Border.all(
                color: theme.primary.withOpacity(0.1),
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
                        gradient: theme.primaryGradient,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withOpacity(0.2),
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
                                      ? theme.text
                                      : theme.textSecondary,
                                  size: _selectedIndex == index 
                                      ? (index == 1 ? 32 : 26)  
                                      : (index == 1 ? 28 : 24), 
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
        ),
        ],
      ),
    );
  }
}