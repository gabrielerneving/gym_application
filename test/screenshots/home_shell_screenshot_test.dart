import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/models/exercise_model.dart';
import 'package:gym_app/models/workout_model.dart';
import 'package:gym_app/pages/main_screen.dart';
import 'package:gym_app/pages/program_detail_page.dart';

import 'screenshot_helpers.dart';

/// The app shell: Home tab with the floating nav bar, the live-workout pill
/// and the program cards (one of them "in progress"), plus a program's own
/// page.
void main() {
  setUpScreenshots();

  // The page swaps this for the live copy from the fake Firestore as soon as
  // it lands, so only the id has to match the seeded program.
  final pushDay = WorkoutProgram(
    id: 'push-day',
    title: 'Push Day',
    exercises: [
      Exercise(id: 'a', name: 'Bench Press', sets: 5, workingSets: 3, warmUpSets: 2),
      Exercise(id: 'b', name: 'Incline Dumbbell Press', sets: 3, workingSets: 3),
      Exercise(id: 'c', name: 'Overhead Press', sets: 4, workingSets: 3, warmUpSets: 1),
      Exercise(id: 'd', name: 'Lateral Raise', sets: 3, workingSets: 3),
    ],
  );

  testWidgets('home + live pill — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: const MainScreen(), workout: demoActiveWorkout()),
    );
    await capture(tester, '10_home_live_pill_dark');
    await tearDownScreen(tester);
  });

  testWidgets('home + live pill resting — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: const MainScreen(),
        theme: kLightTheme,
        workout: demoActiveWorkout(),
        resting: true,
      ),
    );
    await capture(tester, '12_home_live_pill_resting_light');
    await tearDownScreen(tester);
  });

  testWidgets('home, no session — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, screenshotApp(home: const MainScreen()));
    await capture(tester, '13_home_no_session_dark');
    await tearDownScreen(tester);
  });

  testWidgets('home program options sheet — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: const MainScreen(), workout: demoActiveWorkout()),
    );
    await tester.tap(find.byTooltip('Workout options').first);
    await settleFrames(tester);
    await capture(tester, '14_home_program_options_sheet');
    await tearDownScreen(tester);
  });

  testWidgets('program detail — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(ProgramDetailPage(program: pushDay))),
    );
    await capture(tester, '15_program_detail_dark');
    await tearDownScreen(tester);
  });

  testWidgets('program detail, live — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: pushed(ProgramDetailPage(program: pushDay)),
        theme: kLightTheme,
        workout: demoActiveWorkout(),
      ),
    );
    await capture(tester, '16_program_detail_live_light');
    await tearDownScreen(tester);
  });
}
