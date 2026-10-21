import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/rest_timer_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/workout_settings_provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/theme_selector.dart';
import '../widgets/training_goal_sheets.dart';
import '../widgets/ui/ui.dart';

/// The app version, mirrored from `pubspec.yaml` (`version: 1.4.0+18`).
/// `package_info_plus` is not a dependency, so this is kept in sync by hand —
/// bump it whenever the pubspec version changes.
const String _appVersion = '1.4.0';
const String _appBuild = '18';

const String _privacyPolicyUrl =
    'https://gabrielerneving.github.io/gym_application/policy.md';

/// ---------------------------------------------------------------------------
/// Settings — what changes the logging screen first, then goals, looks, and
/// the account.
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
        // --- Workout ---------------------------------------------------------
        const FadeSlideIn(
          index: 0,
          child: SectionHeader(
            title: 'Workout',
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.md,
            ),
          ),
        ),
        FadeSlideIn(
          index: 1,
          child: AppTileGroup(
            children: [
              _ToggleTile(
                icon: Icons.speed_rounded,
                title: 'Show RIR',
                subtitle: 'Log reps in reserve per set',
                value: settings.showRIR,
                onChanged: (v) => ref
                    .read(workoutSettingsProvider.notifier)
                    .toggleShowRIR(v),
              ),
              _ToggleTile(
                icon: Icons.trending_up_rounded,
                title: 'Show progression',
                subtitle: 'Each set against last time',
                value: settings.showProgression,
                onChanged: (v) => ref
                    .read(workoutSettingsProvider.notifier)
                    .toggleShowProgression(v),
              ),
              _ToggleTile(
                icon: Icons.timer_outlined,
                title: 'Rest timer',
                value: settings.showRestTimer,
                onChanged: (v) => ref
                    .read(workoutSettingsProvider.notifier)
                    .toggleShowRestTimer(v),
              ),
              // Only meaningful while the timer is on the screen, so they fold
              // away with it rather than sitting there doing nothing.
              if (settings.showRestTimer)
                _ToggleTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Start rest automatically',
                  subtitle: 'As soon as a set is filled in',
                  value: restTimer.autoStart,
                  onChanged: (v) =>
                      ref.read(restTimerProvider.notifier).setAutoStart(v),
                ),
              if (settings.showRestTimer)
                _RestTargetTile(targetSeconds: restTimer.targetSeconds),
            ],
          ),
        ),

        // --- Goals -----------------------------------------------------------
        const FadeSlideIn(
          index: 2,
          child: SectionHeader(title: 'Goals'),
        ),
        const FadeSlideIn(
          index: 3,
          child: AppTileGroup(
            children: [
              WeeklySetBandTile(),
              SessionsPerWeekTile(),
            ],
          ),
        ),

        // --- Appearance ------------------------------------------------------
        const FadeSlideIn(
          index: 4,
          child: SectionHeader(title: 'Appearance'),
        ),
        const ThemeSelector(),

        // --- Account ---------------------------------------------------------
        const FadeSlideIn(
          index: 5,
          child: SectionHeader(title: 'Account'),
        ),
        FadeSlideIn(
          index: 6,
          child: AppTileGroup(
            children: [
              AppTile(
                bare: true,
                icon: Icons.logout_rounded,
                title: 'Sign out',
                onTap: () => _confirmSignOut(context, ref),
              ),
              AppTile(
                bare: true,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                // It leaves the app, so it says so instead of a chevron.
                trailing: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    right: AppSpacing.xxs,
                  ),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: t.textTertiary,
                  ),
                ),
                onTap: () => _openPrivacyPolicy(context, ref),
              ),
              // Error tone on tile and title, like every destructive action;
              // no chevron — it does not lead anywhere, it asks first.
              AppTile(
                bare: true,
                destructive: true,
                showChevron: false,
                icon: Icons.delete_forever_rounded,
                title: 'Delete account',
                subtitle: 'Erase your account and all workout data',
                onTap: () => _showDeleteAccount(context, ref),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        FadeSlideIn(
          index: 7,
          child: Text(
            'Repicore $_appVersion ($_appBuild)',
            textAlign: TextAlign.center,
            style: AppType.caption(t),
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
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    this.subtitle,
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
      trailing: Padding(
        // AppTile butts its trailing slot against the text; a long subtitle
        // would otherwise run right up to the switch.
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Switch(
          value: value,
          onChanged: _set,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
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
      onTap: () => _pick(context, ref),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: AppSpacing.md),
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
      subtitle: 'The timer fills toward this, then keeps counting',
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
    title: 'Sign out?',
    confirmLabel: 'Sign out',
    icon: Icons.logout_rounded,
  );

  if (!shouldLogout) return;

  await AuthService().signOut();
  // Tillbaka till roten — AuthGate visar AuthScreen när auth state ändras.
  if (context.mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

void _showDeleteAccount(BuildContext context, WidgetRef ref) {
  AppSheet.show<void>(
    context: context,
    ref: ref,
    title: 'Delete account',
    subtitle: 'Your account, programs and workout history are erased for '
        'good. This cannot be undone.',
    builder: (context) => const _DeleteAccountSheet(),
  );
}

/// Asks for the password, then deletes the data and the account.
///
/// The password does two jobs. It is the deliberate "yes, really", and it
/// re-authenticates: Firebase refuses to delete an account without a recent
/// sign-in, and the user's data has to be deleted *while still signed in*,
/// because once the account is gone Firestore no longer lets anyone touch it.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    final email = user.email;
    if (email != null && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final auth = AuthService();

    // Steg 1: Bekräfta att det är rätt person. Fel lösenord kostar ingenting.
    if (email != null) {
      try {
        await auth.reauthenticate(_password.text);
      } on AuthFailure catch (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          // Här finns bara ett fält, så "fel e-post eller lösenord" vore
          // missvisande.
          _error = switch (e.code) {
            'wrong-password' ||
            'invalid-credential' ||
            'INVALID_LOGIN_CREDENTIALS' =>
              'Incorrect password',
            _ => e.message,
          };
        });
        return;
      }
    }

    try {
      // Avbryt ett pågående pass först — annars kan dess autosave skapa
      // active_session-dokumentet på nytt efter att datan raderats.
      await ref.read(workoutProvider.notifier).discardWorkout();
      ref.read(restTimerProvider.notifier).stop();
      // Steg 2: Radera datan medan användaren fortfarande är inloggad.
      await DatabaseService(uid: user.uid).deleteAllUserData();
      // Steg 3: Radera själva kontot.
      await auth.deleteAccount();
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AuthFailure
            ? e.message
            : 'Could not delete your account. Try again.';
      });
      return;
    }

    // Tillbaka till roten: AuthGate ser att ingen är inloggad och visar
    // inloggningen. (Att pusha en egen AuthScreen här skulle lämna appen
    // utan AuthGate, och nästa inloggning skulle då inte leda någonstans.)
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return PopScope<Object?>(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _password,
                obscureText: _obscure,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                style: AppType.body(t),
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _error,
                  suffixIcon: AppIconButton(
                    icon: _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    filled: false,
                    size: 36,
                    iconSize: 19,
                    color: t.textSecondary,
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) {
                  if (!_busy) _delete();
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Cancel',
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton.danger(
                      label: 'Delete',
                      loading: _busy,
                      onPressed: _busy ? null : _delete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openPrivacyPolicy(BuildContext context, WidgetRef ref) async {
  final uri = Uri.parse(_privacyPolicyUrl);

  // För HTTPS-URL:er på Android fungerar canLaunchUrl ofta inte som förväntat,
  // så vi försöker öppna direkt — först externt, sedan i en in-app webview.
  // launchUrl rapporterar oftast misslyckande genom att returnera false, inte
  // genom att kasta, så båda utfallen räknas.
  for (final mode in const [
    LaunchMode.externalApplication,
    LaunchMode.inAppWebView,
  ]) {
    try {
      if (await launchUrl(uri, mode: mode)) return;
    } catch (e) {
      debugPrint('Could not open privacy policy ($mode): $e');
    }
  }

  if (context.mounted) {
    AppSnack.show(
      context,
      ref,
      'Could not open the privacy policy.',
      isError: true,
    );
  }
}
