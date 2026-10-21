import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/pages/main_screen.dart';
import 'package:gym_app/pages/workout_detail_page.dart';

import 'screenshot_helpers.dart';

/// History tab (inside the shell, pill showing) and a session's detail page.
void main() {
  setUpScreenshots();

  testWidgets('history — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: const MainScreen(initialTabIndex: 2),
        workout: demoActiveWorkout(),
      ),
    );
    await capture(tester, '20_history_dark');

    await scrollTo(tester, 1400);
    await capture(tester, '21_history_dark_scrolled');
    await tearDownScreen(tester);
  });

  testWidgets('history — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: const MainScreen(initialTabIndex: 2),
        theme: kLightTheme,
      ),
    );
    await capture(tester, '22_history_light');

    // One program picked in the filter row.
    await tester.tap(find.text('Leg Day').first);
    await settleFrames(tester);
    await capture(tester, '26_history_light_filtered');
    await tearDownScreen(tester);
  });

  testWidgets('workout detail — dark', (tester) async {
    usePhone(tester);
    // The most recent Push Day: warm-ups, a note, deltas vs the week before.
    final session =
        demoHistory.firstWhere((s) => s.programTitle == 'Push Day');
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(WorkoutDetailPage(session: session))),
    );
    await capture(tester, '23_workout_detail_dark');

    await scrollTo(tester, 100000);
    await capture(tester, '24_workout_detail_dark_bottom');
    await tearDownScreen(tester);
  });

  testWidgets('workout detail — light', (tester) async {
    usePhone(tester);
    final session = demoHistory.firstWhere((s) => s.programTitle == 'Leg Day');
    await pumpScreen(
      tester,
      screenshotApp(
        home: pushed(WorkoutDetailPage(session: session)),
        theme: kLightTheme,
      ),
    );
    await capture(tester, '25_workout_detail_light');

    // Edit mode: every set row tappable, the destructive action at the end.
    await tester.tap(find.byTooltip('Edit workout'));
    await settleFrames(tester);
    // Twice: the first jump lands before the "Add set" rows have grown the
    // list, so the end of it is further down than it first reports.
    await scrollTo(tester, 100000);
    await scrollTo(tester, 100000);
    await capture(tester, '27_workout_detail_light_editing');
    await tearDownScreen(tester);
  });
}
