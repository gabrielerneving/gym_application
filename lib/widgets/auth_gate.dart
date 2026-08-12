import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/main_screen.dart';
import '../auth_screen.dart';
import '../services/auth_service.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import 'ui/ui.dart';

// StatefulWidget för att hålla koll på senaste user ID
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastUid;
  bool _wasLoggedIn = false;

  /// Everything keyed to a specific user. Missing one of these here is how a
  /// second account ends up looking at the first account's statistics.
  void _invalidateUserScopedProviders() {
    ref.invalidate(workoutProvider);
    ref.invalidate(currentUidProvider);
    ref.invalidate(workoutSessionsProvider);
    ref.invalidate(exerciseMuscleMapProvider);
    ref.invalidate(trainingDataProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      // Lyssnar på inloggningsstatus
      stream: authService.user,
      builder: (context, snapshot) {
        // Väntar på Firebase - visa bara laddning om vi aldrig har varit inloggade
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Om vi redan var inloggade, visa MainScreen istället för laddning
          // Detta förhindrar "refresh" vid tillfälliga auth-statusändringar
          if (_wasLoggedIn) {
            return const MainScreen();
          }
          return const _SplashScreen();
        }

        // Kontrollera om användaren har ändrats (byte av konto eller utloggning)
        if (snapshot.hasData) {
          final currentUid = snapshot.data!.uid;
          _wasLoggedIn = true;
          
          // Om user ID har ändrats, invalidera workout provider
          // Detta säkerställer att varje användare får sin egen isolerad data
          if (_lastUid != null && _lastUid != currentUid) {
            debugPrint('User changed from $_lastUid to $currentUid - invalidating providers');
            _invalidateUserScopedProviders();
          }
          _lastUid = currentUid;
          
          return const MainScreen();
        }

        // Inte inloggad - rensa senaste UID och invalidera providers
        if (_lastUid != null) {
          debugPrint('User logged out - invalidating providers');
          _invalidateUserScopedProviders();
          _lastUid = null;
        }
        _wasLoggedIn = false;
        
        return const AuthScreen();
      },
    );
  }
}

/// Shown for the brief moment before Firebase reports whether anyone is signed
/// in. Painted in the user's palette so the app never flashes a bare white or
/// black frame on cold start.
class _SplashScreen extends ConsumerWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return AppPage(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlideIn(
              offsetY: 12,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: t.primaryGradientDiagonal,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: t.shadowPrimaryGlow,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 38,
                  color: t.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FadeSlideIn(
              index: 1,
              child: Text('Repicore', style: AppType.title(t)),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: t.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}