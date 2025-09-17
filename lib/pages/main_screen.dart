import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'search_screen.dart';
import 'create_review_screen.dart';
import 'profile_screen.dart';


class MainScreen extends StatefulWidget {
  final int initialTabIndex; 
  const MainScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _animationController;
  late AnimationController _iconAnimationController;

  late final List<Widget> _widgetOptions; 

  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.search_outlined,
    Icons.add_outlined,
    Icons.person_outline,
  ];
  final List<IconData> _activeIcons = [
    Icons.home,
    Icons.search,
    Icons.add,
    Icons.person,
  ];

  @override
  void initState() {
    super.initState();
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
      const SearchScreen(),
      CreateReviewScreen(
        onReviewPosted: (indexToGoTo) {
          setState(() {
            _selectedIndex = indexToGoTo;
          });
        },
      ),
      const ProfileScreen(),
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

  @override
  Widget build(BuildContext context) {
    final double navBarWidth = MediaQuery.of(context).size.width - 32;
    final double itemWidth = navBarWidth / _icons.length; 

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF1B1C20), 
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
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
                            color: const Color(0xFF9542EC).withOpacity(0.2),
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
                                      ? (index == 2 ? 32 : 26)  // Plus-ikonen blir 32px när aktiv
                                      : (index == 2 ? 28 : 24), // Plus-ikonen blir 28px när inaktiv
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