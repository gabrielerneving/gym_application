import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/auth_screen.dart';
import 'package:gym_app/models/exercise_model.dart';
import 'package:gym_app/models/standard_workout_template.dart';
import 'package:gym_app/models/workout_model.dart';
import 'package:gym_app/pages/choose_category_screen.dart';
import 'package:gym_app/pages/create_exercise_screen.dart';
import 'package:gym_app/pages/create_workout.dart';
import 'package:gym_app/pages/exercise_list_screen.dart';
import 'package:gym_app/pages/main_screen.dart';
import 'package:gym_app/pages/settings_screen.dart';
import 'package:gym_app/pages/template_detail_page.dart';

import 'screenshot_helpers.dart';

/// Create tab (empty and editing a program), the templates tab, the exercise
/// picker, Settings and the sign-in screen.
void main() {
  setUpScreenshots();

  final program = WorkoutProgram(
    id: 'leg-day',
    title: 'Leg Day',
    exercises: [
      Exercise(id: 'a', name: 'Back Squat', sets: 5, workingSets: 3, warmUpSets: 2),
      Exercise(id: 'b', name: 'Romanian Deadlift', sets: 4, workingSets: 3, warmUpSets: 1),
      Exercise(id: 'c', name: 'Leg Press', sets: 3, workingSets: 3),
      Exercise(id: 'd', name: 'Lying Leg Curl', sets: 3, workingSets: 3),
      Exercise(id: 'e', name: 'Standing Calf Raise', sets: 4, workingSets: 4),
    ],
  );

  testWidgets('create tab — empty', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: const MainScreen(initialTabIndex: 1)),
    );
    await capture(tester, '40_create_tab_empty_dark');

    await tester.tap(find.text('Templates'));
    await settleFrames(tester);
    await capture(tester, '41_create_templates_dark');
    await tearDownScreen(tester);
  });

  testWidgets('create tab — empty, light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: const MainScreen(initialTabIndex: 1),
        theme: kLightTheme,
      ),
    );
    await capture(tester, '44_create_tab_empty_light');

    await tester.tap(find.text('Templates'));
    await settleFrames(tester);
    await capture(tester, '45_create_templates_light');
    await tearDownScreen(tester);
  });

  testWidgets('create — editing a program', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(CreateWorkoutScreen(workoutToEdit: program))),
    );
    await capture(tester, '42_create_edit_dark');
    await tearDownScreen(tester);
  });

  testWidgets('create — editing a program, light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: pushed(CreateWorkoutScreen(workoutToEdit: program)),
        theme: kLightTheme,
      ),
    );
    await capture(tester, '43_create_edit_light');
    await tearDownScreen(tester);
  });

  testWidgets('exercise picker — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const ChooseCategoryScreen())),
    );
    await capture(tester, '46_exercise_picker_dark');

    await tester.enterText(find.byType(TextField).first, 'press');
    await settleFrames(tester);
    // Drop the keyboard focus so the capture shows the results, not a caret.
    FocusManager.instance.primaryFocus?.unfocus();
    await settleFrames(tester, const Duration(milliseconds: 400));
    await capture(tester, '47_exercise_picker_search_dark');
    await tearDownScreen(tester);
  });

  testWidgets('exercise picker — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: pushed(const ChooseCategoryScreen()),
        theme: kLightTheme,
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'row');
    await settleFrames(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settleFrames(tester, const Duration(milliseconds: 400));
    await capture(tester, '48_exercise_picker_search_light');
    await tearDownScreen(tester);
  });

  testWidgets('category list and new exercise — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const ExerciseListScreen(category: 'Chest'))),
    );
    await capture(tester, '49_exercise_category_dark');
    await tearDownScreen(tester);
  });

  testWidgets('new exercise — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(
        home: pushed(const CreateExerciseScreen()),
        theme: kLightTheme,
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Cable Fly');
    await tester.tap(find.text('Chest'));
    await settleFrames(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settleFrames(tester, const Duration(milliseconds: 400));
    await capture(tester, '4a_new_exercise_light');
    await tearDownScreen(tester);
  });

  testWidgets('template detail — dark', (tester) async {
    usePhone(tester);
    final template = StandardWorkoutTemplate(
      id: 'ppl-beginner',
      title: 'Push Pull Legs',
      description:
          'A classic three-day split. Each muscle once a week, plenty of rest.',
      category: 'Beginner',
      type: 'Push Pull Legs',
      estimatedDurationMinutes: 60,
      exercises: [
        StandardExercise(
          name: 'Bench Press',
          sets: 4,
          workingSets: 3,
          warmUpSets: 1,
          muscleGroups: ['Chest', 'Triceps'],
          notes: 'Feet planted, shoulder blades pinned.',
        ),
        StandardExercise(name: 'Back Squat', sets: 4, workingSets: 3, warmUpSets: 1),
        StandardExercise(name: 'Barbell Row', sets: 3, workingSets: 3, warmUpSets: 0),
      ],
    );
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(TemplateDetailPage(template: template))),
    );
    await capture(tester, '4b_template_detail_dark');
    await tearDownScreen(tester);
  });

  testWidgets('settings — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, screenshotApp(home: pushed(const SettingsScreen())));
    await capture(tester, '50_settings_dark');

    // The palette picker, with the selected tile in view.
    await scrollTo(tester, 620);
    await capture(tester, '50b_settings_dark_appearance');

    await scrollTo(tester, 100000);
    await capture(tester, '51_settings_dark_bottom');
    await tearDownScreen(tester);
  });

  testWidgets('settings — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: pushed(const SettingsScreen()), theme: kLightTheme),
    );
    await capture(tester, '52_settings_light');

    await scrollTo(tester, 100000);
    await capture(tester, '53_settings_light_bottom');
    await tearDownScreen(tester);
  });

  testWidgets('sign in — dark', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, screenshotApp(home: const AuthScreen()));
    await capture(tester, '60_auth_dark');
    await tearDownScreen(tester);
  });

  testWidgets('sign in — light', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      screenshotApp(home: const AuthScreen(), theme: kLightTheme),
    );
    await capture(tester, '61_auth_light');
    await tearDownScreen(tester);
  });
}
