import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/master_exercise_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';

/// Adds a movement to the user's master exercise library.
///
/// Pops the created [MasterExercise] so the caller can drop it straight into
/// the workout being built.
class CreateExerciseScreen extends ConsumerStatefulWidget {
  const CreateExerciseScreen({super.key});

  @override
  ConsumerState<CreateExerciseScreen> createState() =>
      _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends ConsumerState<CreateExerciseScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  String? _selectedCategory;
  bool _isLoading = false;

  /// Set once the user has tried to submit, so the category error only appears
  /// after a real attempt.
  bool _showCategoryError = false;

  /// The categories a master exercise can be filed under. Kept verbatim — the
  /// strings are the Firestore values.
  final List<String> _categories = const [
    'Shoulders',
    'Quads',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Biceps',
    'Triceps',
    'Chest',
    'Back',
    'Abs',
    'Cardio',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _saveExercise() async {
    _nameFocus.unfocus();

    final formValid = _formKey.currentState?.validate() ?? false;
    final categoryValid = _selectedCategory != null;

    if (!categoryValid) setState(() => _showCategoryError = true);
    if (!formValid || !categoryValid) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final newExercise = MasterExercise(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        category: _selectedCategory!,
      );

      await DatabaseService(uid: uid).saveMasterExercise(newExercise);

      if (!mounted) return;
      AppSnack.show(context, ref, '${newExercise.name} added to your library');
      Navigator.of(context).pop(newExercise);
    } catch (e) {
      if (mounted) {
        AppSnack.show(context, ref, 'Could not save the exercise: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _showCategoryError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    return AppScaffold(
      title: 'New exercise',
      subtitle: 'Add a movement to your library',
      bottomPadding: AppSpacing.xxxl,
      children: [
        Form(
          key: _formKey,
          child: FadeSlideIn(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Overline('Exercise name'),
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    style: AppType.body(t).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Incline dumbbell press',
                      counterText: '',
                      prefixIcon: Icon(
                        Icons.fitness_center_rounded,
                        size: 19,
                        color: t.textTertiary,
                      ),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Please enter a name'
                        : null,
                    onFieldSubmitted: (_) => _nameFocus.unfocus(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Overline('Muscle group'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (var i = 0; i < _categories.length; i++)
                        AppChip(
                          label: _categories[i],
                          selected: _selectedCategory == _categories[i],
                          accent: t.dataColor(i),
                          onTap: () => _selectCategory(_categories[i]),
                        ),
                    ],
                  ),
                  if (_showCategoryError) ...[
                    const SizedBox(height: AppSpacing.md),
                    _InlineError(
                      message: 'Please choose a muscle group',
                      theme: t,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Save exercise',
          icon: Icons.check_rounded,
          expand: true,
          size: AppButtonSize.large,
          loading: _isLoading,
          onPressed: _isLoading ? null : _saveExercise,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Saved exercises show up under their muscle group the next time you '
          'add one to a workout.',
          textAlign: TextAlign.center,
          style: AppType.caption(t),
        ),
      ],
    );
  }
}

/// A hairline error row shown under a field group.
class _InlineError extends StatelessWidget {
  final String message;
  final AppColors theme;

  const _InlineError({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 15, color: theme.error),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message,
            style: AppType.caption(theme).copyWith(color: theme.error),
          ),
        ),
      ],
    );
  }
}
