import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/main_screen.dart';
import '../auth_screen.dart';
import '../services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

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

        // Inloggad - visa huvudapp
        if (snapshot.hasData) {
          return const MainScreen();
        }

        // Inte inloggad - visa login
        return const AuthScreen();
      },
    );
  }
}