import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'widgets/auth_gate.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw behind the status and navigation bars — the whole UI is built around
  // edge-to-edge content with a floating nav bar on top.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Repicore',
      debugShowCheckedModeBanner: false,
      theme: AppThemeData.build(appTheme),
      supportedLocales: const [Locale('en')],
      // Keep typography predictable regardless of the OS font-size setting —
      // the layouts here rely on tight metric alignment. Still honours large
      // text up to a sane ceiling.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1.0).clamp(0.9, 1.2),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}
