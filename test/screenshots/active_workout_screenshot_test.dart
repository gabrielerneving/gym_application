import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/models/workout_session_model.dart';
import 'package:gym_app/pages/active_workout_screen.dart';
import 'package:gym_app/providers/rest_timer_provider.dart';
import 'package:gym_app/providers/workout_provider.dart';
import 'package:gym_app/theme/app_theme.dart';

import 'screenshot_helpers.dart';

void main() {
  setUpScreenshots();

  Widget app([
    AppColors theme = kDarkTheme,
    ActiveWorkoutState? workout,
  ]) =>
      screenshotApp(
        home: const ActiveWorkoutScreen(),
        theme: theme,
        workout: workout ?? demoActiveWorkout(),
        resting: true,
      );

  /// The demo session, abandoned two days ago: what the screen offers to
  /// resume or discard when it opens without a live workout.
  ActiveWorkoutState staleWorkout() {
    final live = demoActiveWorkout().session!;
    return ActiveWorkoutState(
      staleSession: WorkoutSession(
        id: live.id,
        programTitle: live.programTitle,
        date: DateTime.now().subtract(const Duration(days: 2)),
        durationInMinutes: live.durationInMinutes,
        completedExercises: live.completedExercises,
      ),
    );
  }

  testWidgets('active workout — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app());
    await capture(tester, '01_active_workout_dark');

    await scrollTo(tester, 560);
    await capture(tester, '02_active_workout_dark_scrolled');

    await scrollTo(tester, 100000);
    await capture(tester, '03_active_workout_dark_bottom');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — light', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app(kLightTheme));
    await capture(tester, '04_active_workout_light');

    await scrollTo(tester, 560);
    await capture(tester, '05_active_workout_light_scrolled');

    await scrollTo(tester, 100000);
    await capture(tester, '05b_active_workout_light_bottom');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — set menu sheet', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app());
    // The third Bench Press working set: still empty, so the sheet offers
    // "Same as last session".
    await tester.tap(find.byTooltip('Set options').at(4));
    await settleFrames(tester);
    await capture(tester, '06_active_workout_set_menu_sheet');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — options sheet', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app());
    await tester.tap(find.byTooltip('Workout options'));
    await settleFrames(tester);
    await capture(tester, '07_active_workout_options_sheet');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — finish dialog and summary', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app());
    await tester.tap(find.text('Finish'));
    await settleFrames(tester);
    await capture(tester, '08_active_workout_finish_dialog');

    // Confirm: the session is saved to the fake Firestore and the summary
    // compares it with last time (minus rows, skipped exercises).
    await tester.tap(find.text('Finish').last);
    await settleFrames(tester, const Duration(milliseconds: 2400));
    await capture(tester, '09_active_workout_complete_dialog');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — summary, light', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app(kLightTheme));
    await tester.tap(find.text('Finish'));
    await settleFrames(tester);
    await capture(tester, '10_active_workout_finish_dialog_light');

    await tester.tap(find.text('Finish').last);
    await settleFrames(tester, const Duration(milliseconds: 2400));
    await capture(tester, '11_active_workout_complete_dialog_light');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — unfinished session', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app(kDarkTheme, staleWorkout()));
    await capture(tester, '12_active_workout_stale_dark');
    await tearDownScreen(tester);

    usePhone(tester);
    await pumpScreen(tester, app(kLightTheme, staleWorkout()));
    await capture(tester, '13_active_workout_stale_light');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — rest timer idle and past target',
      (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: const ActiveWorkoutScreen(),
        theme: kLightTheme,
        workout: demoActiveWorkout(),
      ),
    );
    await capture(tester, '15_active_workout_rest_idle_light');
    await tearDownScreen(tester);

    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: const ActiveWorkoutScreen(),
        workout: demoActiveWorkout(),
        overrides: [
          restTimerProvider
              .overrideWith((ref) => DemoRestTimerNotifier(elapsed: 135)),
        ],
      ),
    );
    await capture(tester, '16_active_workout_rest_overtime_dark');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — typing a set keeps the field focused',
      (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app());

    // The third Bench Press working set: empty, hinting last time's 80 kg.
    // (Typed fields keep their hint in the tree too, so match on both.)
    final weightField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '80' &&
          (widget.controller?.text.isEmpty ?? false),
    );
    final focusNode = tester
        .widget<EditableText>(
          find.descendant(of: weightField, matching: find.byType(EditableText)),
        )
        .focusNode;

    // 85 kg: the set is done (reps come from the hint) and a +5 delta shows
    // up on the value — the field must not be remounted under the user.
    await tester.enterText(weightField, '85');
    await settleFrames(tester, const Duration(milliseconds: 600));
    expect(find.text('+5'), findsOneWidget);

    // Still the same, focused field — not a fresh one that replaced it.
    final typed = tester.widget<EditableText>(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == '85',
      ),
    );
    expect(identical(typed.focusNode, focusNode), isTrue);
    expect(typed.focusNode.hasFocus, isTrue);
    await capture(tester, '17_active_workout_typing_dark');
    await tearDownScreen(tester);
  });

  testWidgets('active workout — add exercise sheet', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, app());
    await scrollTo(tester, 100000);
    await tester.tap(find.text('Add exercise'));
    await settleFrames(tester);

    // Pick "Dips" from the library search; the set-count sheet follows.
    await tester.enterText(find.byType(TextField).first, 'Dips');
    await settleFrames(tester);
    await tester.tap(find.text('Dips').last);
    await settleFrames(tester, const Duration(milliseconds: 1600));
    await capture(tester, '14_active_workout_add_exercise_sheet');
    await tearDownScreen(tester);
  });
}
