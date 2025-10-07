import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/auth_gate.dart';
import 'providers/theme_provider.dart';

void main() async {
  // Initiera Flutter och Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Wrapper för Riverpod state management
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme provider for dynamic theme switching
    final appTheme = ref.watch(themeProvider);
    
    return MaterialApp(
      title: 'Workouts App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: appTheme.background,
        primarySwatch: appTheme.toMaterialColor(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: appTheme.primary,
          brightness: Brightness.dark,
          primary: appTheme.primary,
          secondary: appTheme.accent,
          surface: appTheme.surface,
          error: appTheme.error,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: appTheme.text),
        ),
        cardColor: appTheme.card,
      ),
        
      supportedLocales: const [
        Locale('en'), 
      ],
      home: const AuthGate(),
    );
  }
}