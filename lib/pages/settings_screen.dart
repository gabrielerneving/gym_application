import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../widgets/theme_selector.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';

Future<void> _showLogoutConfirmation(BuildContext context, WidgetRef ref) async {
  final theme = ref.watch(themeProvider);
  
  final bool? shouldLogout = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Sign Out',
          style: TextStyle(
            color: theme.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.primary,
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );

  if (shouldLogout == true) {
    await AuthService().signOut();
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: currentTheme.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: currentTheme.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: currentTheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: currentTheme.text),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Theme Section
          const ThemeSelector(),

          const SizedBox(height: 32),

          // Workout Features Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Workout Features',
              style: TextStyle(
                color: currentTheme.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          _WorkoutFeatureToggle(
            icon: Icons.fitness_center,
            title: 'Show RIR (Reps in Reserve)',
            subtitle: 'Track how many reps you have left in the tank',
            settingKey: 'rir',
          ),

          _WorkoutFeatureToggle(
            icon: Icons.trending_up,
            title: 'Show Progression Indicators',
            subtitle: 'See +/- rep changes compared to last workout',
            settingKey: 'progression',
          ),

          const SizedBox(height: 32),

                // App Info Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'About',
                    style: TextStyle(
                      color: currentTheme.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(
                      color: currentTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: null,
                ),

                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: currentTheme.textSecondary,
                    size: 16,
                  ),
                  onTap: () {
                    // TODO: Open privacy policy
                  },
                ),

                const SizedBox(height: 32),

                // Logout Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showLogoutConfirmation(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentTheme.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout),
                          SizedBox(width: 8),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SettingsTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: currentTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: currentTheme.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: currentTheme.text,
            fontSize: 16,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _WorkoutFeatureToggle extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String settingKey;

  const _WorkoutFeatureToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.settingKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final workoutSettings = ref.watch(workoutSettingsProvider);
    
    final bool currentValue = settingKey == 'rir' 
        ? workoutSettings.showRIR 
        : workoutSettings.showProgression;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: currentTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: currentTheme.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: currentTheme.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: currentTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        value: currentValue,
        activeColor: currentTheme.primary,
        onChanged: (bool value) {
          if (settingKey == 'rir') {
            ref.read(workoutSettingsProvider.notifier).toggleShowRIR(value);
          } else {
            ref.read(workoutSettingsProvider.notifier).toggleShowProgression(value);
          }
        },
      ),
    );
  }
}
