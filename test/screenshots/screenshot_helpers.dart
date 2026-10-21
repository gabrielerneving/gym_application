// Screenshot harness: renders real screens with fake data in a widget test and
// writes PNGs to disk, so the UI can be looked at without building the app.
//
// Run:   flutter test --no-pub test/screenshots/
// Output: $SCREENSHOT_DIR (env var or --dart-define), default build/screenshots
//
// Firebase is faked underneath the plugins (fake_firebase.dart) and seeded
// with demo_data.dart, so screens run their real data code. Needs
// lib/config/admin_config.dart (gitignored) to exist for HomeScreen to compile.
//
// Fidelity fixes over a plain widget test — none of them touch app code:
//  * Text uses the real Roboto and icons the real MaterialIcons, both from the
//    Flutter SDK cache, instead of the test font's black boxes. The app's theme
//    sets no fontFamily (on Android that means Roboto) and flutter_tester maps
//    a missing family straight to its box font, so the harness sets
//    `fontFamily: 'Roboto'` on the theme's text themes, and patches the few
//    paragraphs that do not inherit from the theme just before each capture.
//  * Shadows are drawn blurred, as on a device (`debugDisableShadows = false`).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/providers/rest_timer_provider.dart';
import 'package:gym_app/providers/theme_provider.dart';
import 'package:gym_app/providers/workout_provider.dart';
import 'package:gym_app/theme/app_theme.dart';
import 'package:gym_app/theme/app_theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';
import 'fake_firebase.dart';

export 'demo_data.dart';

/// iPhone 14/15-sized logical canvas with a notch and a home indicator.
const Size kPhoneSize = Size(390, 844);
const double kSafeTop = 47;
const double kSafeBottom = 34;
const double kDevicePixelRatio = 3;

/// Resolution of the written PNGs (logical px × this).
const double kCapturePixelRatio = 2;

/// What an unnamed text style renders as on Android.
const String kFontFamily = 'Roboto';

const AppColors kDarkTheme = AppTheme.emberTheme; // the default palette
const AppColors kLightTheme = AppTheme.blossomTheme;

const String _dirDefine = String.fromEnvironment('SCREENSHOT_DIR');

/// Where PNGs go: `--dart-define=SCREENSHOT_DIR=…`, else the `SCREENSHOT_DIR`
/// environment variable, else `build/screenshots`.
String get screenshotDir {
  if (_dirDefine.isNotEmpty) return _dirDefine;
  final env = Platform.environment['SCREENSHOT_DIR'];
  if (env != null && env.isNotEmpty) return env;
  return 'build${Platform.pathSeparator}screenshots';
}

final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'screenshot');

/// Call once at the top of `main()` in every screenshot test file.
void setUpScreenshots({Map<String, Object> prefs = const {}}) {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
    final store = await installFakeFirebase(
      uid: demoUid,
      email: demoEmail,
      displayName: demoName,
    );
    seedDemoData(store);
    Directory(screenshotDir).createSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      // The deltas under logged sets are an opt-in setting — show them.
      'show_progression': true,
      ...prefs,
    });
  });
}

/// Phone-sized view with real-looking safe areas, and real (blurred)
/// shadows — flutter_test flattens them to hard outlines by default, which
/// makes every card look like it has a black lip. Undone by [tearDownScreen].
void usePhone(WidgetTester tester) {
  debugDisableShadows = false;
  tester.view
    ..physicalSize = kPhoneSize * kDevicePixelRatio
    ..devicePixelRatio = kDevicePixelRatio
    ..padding = const FakeViewPadding(
      top: kSafeTop * kDevicePixelRatio,
      bottom: kSafeBottom * kDevicePixelRatio,
    )
    ..viewPadding = const FakeViewPadding(
      top: kSafeTop * kDevicePixelRatio,
      bottom: kSafeBottom * kDevicePixelRatio,
    );
  addTearDown(tester.view.reset);
}

/// The app shell the screens normally sit in (same theme and text-scale
/// clamp as `MyApp`), wrapped in a boundary [capture] can read back.
Widget screenshotApp({
  required Widget home,
  AppColors theme = kDarkTheme,
  ActiveWorkoutState? workout,
  bool resting = false,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      themeProvider.overrideWith(
        (ref) => ThemeNotifier(initialIndex: AppTheme.getThemeIndex(theme)),
      ),
      workoutProvider.overrideWith(
        (ref) => DemoWorkoutNotifier(workout ?? ActiveWorkoutState()),
      ),
      if (resting)
        restTimerProvider.overrideWith((ref) => DemoRestTimerNotifier()),
      ...overrides,
    ],
    child: RepaintBoundary(
      key: _boundaryKey,
      child: Consumer(
        builder: (context, ref, _) {
          final t = ref.watch(themeProvider);
          return MaterialApp(
            title: 'Repicore',
            debugShowCheckedModeBanner: false,
            theme: _withFont(AppThemeData.build(t)),
            supportedLocales: const [Locale('en')],
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
            home: home,
          );
        },
      ),
    ),
  );
}

/// A home route that immediately pushes [page], so pushed screens get their
/// back button and route transition exactly as in the app.
Widget pushed(Widget page) => _PushOnStart(page: page);

class _PushOnStart extends StatefulWidget {
  final Widget page;
  const _PushOnStart({required this.page});

  @override
  State<_PushOnStart> createState() => _PushOnStartState();
}

class _PushOnStartState extends State<_PushOnStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => widget.page),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
}

ThemeData _withFont(ThemeData theme) => theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: kFontFamily),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: kFontFamily),
    );

/// Pumps [app] and lets entrance animations, staggered fade-ins and the fake
/// Firestore streams finish. Uses fixed steps rather than `pumpAndSettle`,
/// which never returns while a looping animation (live dot, shimmer) runs.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget app, {
  Duration settle = const Duration(milliseconds: 1600),
}) async {
  await tester.pumpWidget(app);
  await settleFrames(tester, settle);
}

Future<void> settleFrames(
  WidgetTester tester, [
  Duration total = const Duration(milliseconds: 1200),
]) async {
  const step = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Jumps the [index]th scrollable on screen to [offset] (clamped).
Future<void> scrollTo(
  WidgetTester tester,
  double offset, {
  int index = 0,
}) async {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).at(index));
  final position = state.position;
  position.jumpTo(offset.clamp(position.minScrollExtent, position.maxScrollExtent));
  await settleFrames(tester, const Duration(milliseconds: 600));
}

/// Writes the current frame to `<screenshotDir>/<name>.png`.
Future<File> capture(WidgetTester tester, String name) async {
  // A rebuild in the frame that lays the patch out can hand a paragraph its
  // original span back, so repeat until a frame passes with nothing to patch.
  for (var i = 0; i < 6 && _patchUnnamedFonts(tester) > 0; i++) {
    await tester.pump();
  }
  final boundary = _boundaryKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  final file = File('$screenshotDir${Platform.pathSeparator}$name.png');
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kCapturePixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('screenshot: ${file.absolute.path}');
  return file;
}

/// Gives every laid-out paragraph whose style names no font family the one an
/// Android phone would use. The theme patch above covers text that inherits
/// from the theme; this covers the rest (`AnimatedDefaultTextStyle` with a
/// complete style, e.g. the segmented control). Render-level only — the
/// app's widgets are untouched. Returns how many paragraphs it changed.
int _patchUnnamedFonts(WidgetTester tester) {
  var changed = 0;
  void visit(RenderObject object) {
    if (object is RenderParagraph) {
      final span = object.text;
      if (span is TextSpan && span.style?.fontFamily == null) {
        object.text = TextSpan(
          text: span.text,
          children: span.children,
          style: (span.style ?? const TextStyle())
              .copyWith(fontFamily: kFontFamily),
          recognizer: span.recognizer,
          mouseCursor: span.mouseCursor,
          semanticsLabel: span.semanticsLabel,
          locale: span.locale,
          spellOut: span.spellOut,
        );
        changed++;
      }
    }
    object.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return changed;
}

/// Tears the tree down so tickers and providers are disposed inside the
/// test, and restores the shadow flag flutter_test checks after every test.
Future<void> tearDownScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  debugDisableShadows = true;
}

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  // <flutter>/bin/cache/artifacts/engine/<platform>/flutter_tester(.exe)
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  return dir.path;
}

Future<ByteData> _fontBytes(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

Future<void> _loadFonts() async {
  final sep = Platform.pathSeparator;
  final fonts = [
    _flutterRoot(),
    'bin',
    'cache',
    'artifacts',
    'material_fonts',
  ].join(sep);

  final roboto = FontLoader(kFontFamily);
  for (final file in const [
    'roboto-light.ttf',
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(_fontBytes('$fonts$sep$file'));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(_fontBytes('$fonts${sep}materialicons-regular.otf'));
  await icons.load();
}
