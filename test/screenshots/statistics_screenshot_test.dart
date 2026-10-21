import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/pages/consistency_screen.dart';
import 'package:gym_app/pages/exercise_compare_screen.dart';
import 'package:gym_app/pages/main_screen.dart';
import 'package:gym_app/pages/muscle_groups_screen.dart';
import 'package:gym_app/pages/one_rm_screen.dart';
import 'package:gym_app/pages/progression_screen.dart';
import 'package:gym_app/pages/records_screen.dart';
import 'package:gym_app/pages/volume_tracker_screen.dart';
import 'package:gym_app/widgets/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screenshot_helpers.dart';

/// The Stats hub and every screen it opens, fed by ~8 weeks of fake sessions
/// through the real DatabaseService → workoutSessionsProvider →
/// trainingDataProvider chain.
///
/// Sub-pages are numbered 360–399 so they sort between the hub (30–35) and
/// the Create tab (40+).
void main() {
  setUpScreenshots();

  // --- The hub ---------------------------------------------------------------

  testWidgets('statistics — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: const MainScreen(initialTabIndex: 3)),
      settle: const Duration(milliseconds: 2400),
    );
    await capture(tester, '30_statistics_dark');

    await scrollTo(tester, 480);
    await capture(tester, '31_statistics_dark_insights');

    await scrollTo(tester, 1050);
    await capture(tester, '32_statistics_dark_consistency_muscles');

    await scrollTo(tester, 100000);
    await capture(tester, '33_statistics_dark_bottom');
    await tearDownScreen(tester);
  });

  testWidgets('statistics — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: const MainScreen(initialTabIndex: 3), theme: kLightTheme),
      settle: const Duration(milliseconds: 2400),
    );
    await capture(tester, '34_statistics_light');

    await scrollTo(tester, 480);
    await capture(tester, '35_statistics_light_volume');

    await scrollTo(tester, 1050);
    await capture(tester, '350_statistics_light_muscles');
    await tearDownScreen(tester);
  });

  // --- Records ---------------------------------------------------------------

  testWidgets('records — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, screenshotApp(home: pushed(const RecordsScreen())));
    await capture(tester, '360_records_dark');
    await tearDownScreen(tester);
  });

  testWidgets('records — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const RecordsScreen()), theme: kLightTheme),
    );
    await capture(tester, '361_records_light');
    await tearDownScreen(tester);
  });

  // --- Progression and compare -----------------------------------------------

  testWidgets('progression — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const ProgressionScreen())),
    );
    await capture(tester, '365_progression_dark');

    await scrollTo(tester, 560);
    await capture(tester, '366_progression_dark_sessions');
    await tearDownScreen(tester);
  });

  testWidgets('progression — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const ProgressionScreen()), theme: kLightTheme),
    );
    await capture(tester, '367_progression_light');
    await tearDownScreen(tester);
  });

  testWidgets('compare — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: pushed(
          const ExerciseCompareScreen(
            initialA: 'Bench Press',
            initialB: 'Back Squat',
          ),
        ),
      ),
    );
    await capture(tester, '370_compare_dark');

    await scrollTo(tester, 100000);
    await capture(tester, '371_compare_dark_table');
    await tearDownScreen(tester);
  });

  testWidgets('compare — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: pushed(
          const ExerciseCompareScreen(
            initialA: 'Bench Press',
            initialB: 'Back Squat',
          ),
        ),
        theme: kLightTheme,
      ),
    );
    await capture(tester, '372_compare_light');
    await tearDownScreen(tester);
  });

  // --- 1RM -------------------------------------------------------------------

  testWidgets('1RM — dark, list and detail', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, screenshotApp(home: pushed(const OneRMScreen())));
    await capture(tester, '375_one_rm_dark');

    // The first card is the strongest lift; its detail page holds the table.
    await tester.tap(find.byType(AppCard).first);
    await settleFrames(tester, const Duration(milliseconds: 1600));
    await capture(tester, '377_one_rm_detail_dark');

    await scrollTo(tester, 100000);
    await capture(tester, '378_one_rm_detail_dark_bottom');
    await tearDownScreen(tester);
  });

  testWidgets('1RM — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const OneRMScreen()), theme: kLightTheme),
    );
    await capture(tester, '376_one_rm_light');

    await tester.tap(find.byType(AppCard).first);
    await settleFrames(tester, const Duration(milliseconds: 1600));
    await capture(tester, '379_one_rm_detail_light');
    await tearDownScreen(tester);
  });

  // --- Volume ----------------------------------------------------------------

  testWidgets('volume — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const VolumeTrackerScreen())),
    );
    await capture(tester, '380_volume_dark');

    await scrollTo(tester, 100000);
    await capture(tester, '381_volume_dark_muscles');
    await tearDownScreen(tester);
  });

  testWidgets('volume — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const VolumeTrackerScreen()), theme: kLightTheme),
    );
    await capture(tester, '382_volume_light');
    await tearDownScreen(tester);
  });

  // --- Consistency -----------------------------------------------------------

  testWidgets('consistency — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const ConsistencyScreen())),
    );
    await capture(tester, '385_consistency_dark');

    await scrollTo(tester, 100000);
    await capture(tester, '386_consistency_dark_weekdays');
    await tearDownScreen(tester);
  });

  testWidgets('consistency — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const ConsistencyScreen()), theme: kLightTheme),
    );
    await capture(tester, '387_consistency_light');
    await tearDownScreen(tester);
  });

  // --- Muscle groups ---------------------------------------------------------

  testWidgets('muscle groups — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const MuscleGroupsScreen())),
    );
    await capture(tester, '390_muscles_dark');

    await scrollTo(tester, 520);
    await capture(tester, '391_muscles_dark_breakdown');

    await scrollTo(tester, 100000);
    await capture(tester, '392_muscles_dark_bottom');

    // The legend under the bars opens the band editor.
    await tester.tap(find.text('Change'));
    await settleFrames(tester, const Duration(milliseconds: 900));
    await capture(tester, '396_band_sheet_dark');
    await tearDownScreen(tester);
  });

  // The demo history sits below the default 10–20 band everywhere. A lower,
  // user-chosen band puts some groups on target and one above it, so the
  // green and amber states get looked at too.
  testWidgets('muscle groups — a band some groups hit', (tester) async {
    SharedPreferences.setMockInitialValues({
      'show_progression': true,
      'goal_weekly_sets_min': 5,
      'goal_weekly_sets_max': 9,
    });
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: const MainScreen(initialTabIndex: 3)),
      settle: const Duration(milliseconds: 2400),
    );
    await scrollTo(tester, 1050);
    await capture(tester, '394_statistics_dark_muscles_on_target');
    await tearDownScreen(tester);

    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const MuscleGroupsScreen()), theme: kLightTheme),
    );
    await scrollTo(tester, 520);
    await capture(tester, '395_muscles_light_on_target');
    await tearDownScreen(tester);
  });

  testWidgets('muscle groups — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const MuscleGroupsScreen()), theme: kLightTheme),
    );
    await scrollTo(tester, 520);
    await capture(tester, '393_muscles_light_breakdown');
    await tearDownScreen(tester);
  });
}
