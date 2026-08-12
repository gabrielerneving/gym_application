import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth_screen.dart';
import '../providers/rest_timer_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/theme_selector.dart';
import '../widgets/ui/ui.dart';

/// The app version, mirrored from `pubspec.yaml` (`version: 1.3.0+15`).
/// `package_info_plus` is not a dependency, so this is kept in sync by hand —
/// bump it whenever the pubspec version changes.
const String _appVersion = '1.3.0';
const String _appBuild = '15';

const String _privacyPolicyUrl =
    'https://gabrielerneving.github.io/gym_application/policy.md';

/// ---------------------------------------------------------------------------
/// Settings — appearance, workout options, the account and the legal bits.
/// ---------------------------------------------------------------------------
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final settings = ref.watch(workoutSettingsProvider);
    final restTimer = ref.watch(restTimerProvider);
    final email = FirebaseAuth.instance.currentUser?.email;

    return AppScaffold(
      title: 'Settings',
      subtitle: email,
      bottomPadding: AppSpacing.huge,
      children: [
        // --- Appearance ------------------------------------------------------
        const FadeSlideIn(
          index: 0,
          child: SectionHeader(
            title: 'Appearance',
            subtitle: 'Pick a palette — every screen follows it.',
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.md,
            ),
          ),
        ),
        const ThemeSelector(),

        // --- Workout ---------------------------------------------------------
        const FadeSlideIn(
          index: 1,
          child: SectionHeader(
            title: 'Workout',
            subtitle: 'Extra detail while you are logging sets.',
          ),
        ),
        FadeSlideIn(
          index: 2,
          child: AppTileGroup(
            children: [
              _ToggleTile(
                icon: Icons.speed_rounded,
                title: 'Show RIR',
                subtitle: 'Track how many reps you have left in the tank',
                value: settings.showRIR,
                onChanged: (v) => ref
                    .read(workoutSettingsProvider.notifier)
                    .toggleShowRIR(v),
              ),
              _ToggleTile(
                icon: Icons.trending_up_rounded,
                title: 'Show progression',
                subtitle: 'See +/- rep changes compared to last workout',
                value: settings.showProgression,
                onChanged: (v) => ref
                    .read(workoutSettingsProvider.notifier)
                    .toggleShowProgression(v),
              ),
              _ToggleTile(
                icon: Icons.timer_outlined,
                title: 'Rest timer',
                subtitle: 'A floating timer that counts your rest between sets',
                value: settings.showRestTimer,
                onChanged: (v) => ref
                    .read(workoutSettingsProvider.notifier)
                    .toggleShowRestTimer(v),
              ),
              // Only meaningful while the timer is on the screen, so it folds
              // away with it rather than sitting there doing nothing.
              if (settings.showRestTimer)
                _ToggleTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Start rest automatically',
                  subtitle: 'Begin the rest as soon as a set is filled in',
                  value: restTimer.autoStart,
                  onChanged: (v) =>
                      ref.read(restTimerProvider.notifier).setAutoStart(v),
                ),
              if (settings.showRestTimer)
                _RestTargetTile(targetSeconds: restTimer.targetSeconds),
            ],
          ),
        ),

        // --- Account ---------------------------------------------------------
        const FadeSlideIn(
          index: 3,
          child: SectionHeader(title: 'Account'),
        ),
        FadeSlideIn(
          index: 4,
          child: AppTileGroup(
            children: [
              AppTile(
                bare: true,
                icon: Icons.logout_rounded,
                title: 'Sign out',
                subtitle: 'You can sign back in at any time',
                onTap: () => _confirmSignOut(context, ref),
              ),
              AppTile(
                bare: true,
                icon: Icons.delete_forever_rounded,
                iconColor: t.error,
                title: 'Delete account',
                subtitle: 'Permanently erase your account and all its data',
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ),

        // --- About -----------------------------------------------------------
        const FadeSlideIn(
          index: 5,
          child: SectionHeader(title: 'About'),
        ),
        FadeSlideIn(
          index: 6,
          child: AppTileGroup(
            children: [
              AppTile(
                bare: true,
                icon: Icons.info_outline_rounded,
                title: 'Version',
                subtitle: 'Repicore · build $_appBuild',
                showChevron: false,
                trailing: Text(
                  _appVersion,
                  style: AppType.mono(t, size: 14).copyWith(
                    color: t.textSecondary,
                  ),
                ),
              ),
              AppTile(
                bare: true,
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy policy',
                subtitle: 'How your training data is handled',
                onTap: () => _openPrivacyPolicy(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A settings row whose trailing control is a switch. Tapping anywhere on the
/// row flips it, which is a far bigger target than the switch alone.
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  void _set(bool next) {
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppTile(
      bare: true,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _set(!value),
      trailing: Switch(
        value: value,
        onChanged: _set,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Picks the rest target without leaving Settings. The same value backs the
/// picker inside the timer's own sheet, so the two can never disagree.
class _RestTargetTile extends ConsumerWidget {
  final int targetSeconds;

  const _RestTargetTile({required this.targetSeconds});

  static String _label(int seconds) {
    if (seconds == 0) return 'No target';
    if (seconds % 60 == 0) return '${seconds ~/ 60} min';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppTile(
      bare: true,
      icon: Icons.hourglass_bottom_rounded,
      title: 'Target rest',
      subtitle: targetSeconds == 0
          ? 'The timer just counts up'
          : 'The ring fills toward this, then keeps counting',
      onTap: () => _pick(context, ref),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label(targetSeconds),
            style: AppType.mono(t, size: 14).copyWith(color: t.primary),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
        ],
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    AppSheet.show<void>(
      context: context,
      ref: ref,
      title: 'Target rest',
      subtitle: 'How long you aim to rest between working sets',
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(
            restTimerProvider.select((s) => s.targetSeconds),
          );
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final preset in RestTimerNotifier.targetPresets)
                AppChip(
                  label: _label(preset),
                  selected: current == preset,
                  onTap: () =>
                      ref.read(restTimerProvider.notifier).setTarget(preset),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final shouldLogout = await AppDialog.confirm(
    context: context,
    ref: ref,
    title: 'Sign Out',
    message: 'Are you sure you want to sign out?',
    confirmLabel: 'Sign Out',
    icon: Icons.logout_rounded,
  );

  if (!shouldLogout) return;

  await AuthService().signOut();
  // Navigera tillbaka till föregående skärm efter utloggning.
  // AuthGate kommer automatiskt att visa AuthScreen när auth state ändras.
  if (context.mounted) {
    Navigator.of(context).pop();
  }
}

Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final shouldDelete = await AppDialog.confirm(
    context: context,
    ref: ref,
    title: 'Delete Account',
    message: 'Are you sure you want to delete your account?\n\n'
        'This action is IRREVERSIBLE and will:\n'
        '• Delete all your workout data\n'
        '• Delete all your exercise history\n'
        '• Delete your account permanently\n'
        '• Cannot be undone!',
    confirmLabel: 'Delete Forever',
    destructive: true,
  );

  if (!shouldDelete) return;
  if (!context.mounted) return;

  await _performAccountDeletion(context, ref);
}

Future<void> _performAccountDeletion(
  BuildContext context,
  WidgetRef ref,
) async {
  final theme = ref.read(themeProvider);

  // Blocking progress dialog. It is dismissed by hand in every branch below.
  AppDialog.show<void>(
    context: context,
    ref: ref,
    title: 'Deleting account',
    message: 'Removing your account and all of its data…',
    icon: Icons.delete_forever_rounded,
    iconColor: theme.error,
    barrierDismissible: false,
    content: const LoadingState(),
  );

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;

      // Step 1: Delete Firebase Auth account FIRST.
      // If this fails (e.g. requires-recent-login), user keeps their data.
      await AuthService().deleteAccount();

      // Step 2: Delete user data from Firestore (only if auth delete succeeded)
      final dbService = DatabaseService(uid: uid);
      await dbService.deleteAllUserData();

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        // Navigate to auth screen manually to ensure immediate transition
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } else {
      // Nobody signed in — nothing to delete, but the dialog must still go.
      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnack.show(
          context,
          ref,
          'No account is currently signed in.',
          isError: true,
        );
      }
    }
  } catch (e) {
    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();

      // Show error dialog. Firebase asks for a recent sign-in before it will
      // delete an account, and that message has to reach the user verbatim.
      await AppDialog.info(
        context: context,
        ref: ref,
        title: 'Error',
        message: 'Failed to delete account: ${e.toString()}',
        buttonLabel: 'OK',
        icon: Icons.error_outline_rounded,
      );
    }
  }
}

Future<void> _openPrivacyPolicy(BuildContext context, WidgetRef ref) async {
  final uri = Uri.parse(_privacyPolicyUrl);

  try {
    // För HTTPS-URL:er på Android fungerar canLaunchUrl ofta inte som förväntat.
    // Vi försöker öppna direkt istället.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not open privacy policy: $e');
    // Försök med in-app webview som fallback.
    try {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } catch (e2) {
      debugPrint('Could not open in webview either: $e2');
      if (context.mounted) {
        AppSnack.show(
          context,
          ref,
          'Could not open the privacy policy.',
          isError: true,
        );
      }
    }
  }
}
