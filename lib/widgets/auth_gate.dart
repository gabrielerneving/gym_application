import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/main_screen.dart';
import '../auth_screen.dart';
import '../services/auth_service.dart';
import '../providers/workout_provider.dart';

// StatefulWidget för att hålla koll på senaste user ID
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      // Lyssnar på inloggningsstatus
      stream: authService.user,
      builder: (context, snapshot) {
        // Väntar på Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Kontrollera om användaren har ändrats (byte av konto eller utloggning)
        if (snapshot.hasData) {
          final currentUid = snapshot.data!.uid;
          
          // Om user ID har ändrats, invalidera workout provider
          // Detta säkerställer att varje användare får sin egen isolerad data
          if (_lastUid != null && _lastUid != currentUid) {
            print('User changed from $_lastUid to $currentUid - invalidating workout provider');
            ref.invalidate(workoutProvider);
          }
          _lastUid = currentUid;
          
          return const MainScreen();
        }

        // Inte inloggad - rensa senaste UID och invalidera providers
        if (_lastUid != null) {
          print('User logged out - invalidating workout provider');
          ref.invalidate(workoutProvider);
          _lastUid = null;
        }
        
        return const AuthScreen();
      },
    );
  }
}