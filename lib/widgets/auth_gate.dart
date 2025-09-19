import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/main_screen.dart'; // Din hemskärm med bottom nav bar
import '../auth_screen.dart'; // Din inloggningsskärm
import '../services/auth_service.dart'; // Din auth service

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Skapa en instans av din AuthService för att komma åt streamen
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      // Lyssna på user-streamen. Denna skickar ett User-objekt
      // om någon är inloggad, och null om ingen är det.
      stream: authService.user,
      builder: (context, snapshot) {
        // 1. Om vi väntar på data från Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Visa en enkel laddningsindikator medan vi kollar inloggningsstatus
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Om vi har fått data OCH datan är ett User-objekt (dvs. inte null)
        if (snapshot.hasData) {
          // Användaren är inloggad, visa hemskärmen!
          return const MainScreen();
        }

        // 3. Om vi har fått data men den är null, eller om vi inte har någon data alls
        // Användaren är utloggad, visa inloggningsskärmen!
        return const AuthScreen();
      },
    );
  }
}