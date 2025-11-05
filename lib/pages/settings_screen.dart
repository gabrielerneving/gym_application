import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/theme_selector.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../auth_screen.dart';

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
    // Navigera tillbaka till föregående skärm efter utloggning
    // AuthGate kommer automatiskt att visa AuthScreen när auth state ändras
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

Future<void> _showDeleteAccountConfirmation(BuildContext context, WidgetRef ref) async {
  final theme = ref.watch(themeProvider);
  
  final bool? shouldDelete = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Account',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(color: theme.text, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              '⚠️ This action is IRREVERSIBLE and will:',
              style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '• Delete all your workout data\n• Delete all your exercise history\n• Delete your account permanently\n• Cannot be undone!',
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Delete Forever',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );

  if (shouldDelete == true) {
    await _performAccountDeletion(context, ref);
  }
}

Future<void> _performAccountDeletion(BuildContext context, WidgetRef ref) async {
  final theme = ref.watch(themeProvider);
  
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: theme.card,
      content: Row(
        children: [
          CircularProgressIndicator(color: theme.primary),
          const SizedBox(width: 20),
          Text('Deleting account...', style: TextStyle(color: theme.text)),
        ],
      ),
    ),
  );

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Step 1: Delete user data from Firestore
      final dbService = DatabaseService(uid: user.uid);
      await dbService.deleteAllUserData();
      
      // Step 2: Delete Firebase Auth account
      await AuthService().deleteAccount();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Navigate to auth screen manually to ensure immediate transition
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  } catch (e) {
    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.card,
          title: Text('Error', style: TextStyle(color: theme.text)),
          content: Text(
            'Failed to delete account: ${e.toString()}',
            style: TextStyle(color: theme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: theme.primary)),
            ),
          ],
        ),
      );
    }
  }
}

Future<void> _openPrivacyPolicy() async {
  const url = 'https://gabrielerneving.github.io/gym_application/policy.md';
  final uri = Uri.parse(url);

  try {
    // För HTTPS-URL:er på Android fungerar canLaunchUrl ofta inte som förväntat
    // Vi försöker öppna direkt istället
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    print('Could not open privacy policy: $e');
    // Försök med in-app webview som fallback
    try {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } catch (e2) {
      print('Could not open in webview either: $e2');
      // Här kan du visa en dialog till användaren
    }
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
      body: SingleChildScrollView(
        child: Column(
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
                    '1.0.7',
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
                  onTap: () => _openPrivacyPolicy(),
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

                const SizedBox(height: 16),

                // Delete Account Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showDeleteAccountConfirmation(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_forever),
                          SizedBox(width: 8),
                          Text(
                            'Delete Account',
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
