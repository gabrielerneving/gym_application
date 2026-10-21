import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/master_exercise_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';
import 'exercise_list_screen.dart';

/// Adds a movement to the user's master exercise library.
///
/// Pops the created [MasterExercise] so the caller can drop it straight into
/// the workout being built. Typing a name that is already in the library pops
/// that entry instead: statistics map exercises to muscle groups by name, so a
/// second copy would only split (or overwrite) its history.
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

  StreamSubscription<List<MasterExercise>>? _librarySub;
  List<MasterExercise> _library = const <MasterExercise>[];

  String? _selectedCategory;
  bool _isLoading = false;

  /// Set once the user has tried to submit, so the category error only appears
  /// after a real attempt.
  bool _showCategoryError = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _librarySub = watchExerciseLibrary(uid).listen(
        (library) {
          if (mounted) setState(() => _library = library);
        },
        // Only powers the duplicate check — saving still works without it.
        onError: (Object _) {},
      );
    }
  }

  @override
  void dispose() {
    _librarySub?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  /// The library entry with the typed name, if there is one.
  MasterExercise? get _existing {
    final key = _nameController.text.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final exercise in _library) {
      if (exercise.name.trim().toLowerCase() == key) return exercise;
    }
    return null;
  }

  Future<void> _saveExercise() async {
    _nameFocus.unfocus();

    final existing = _existing;
    if (existing != null) {
      Navigator.of(context).pop(existing);
      return;
    }

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
      // Statistics map names to muscle groups from the library.
      ref.invalidate(exerciseMuscleMapProvider);

      if (!mounted) return;
      AppSnack.show(context, ref, '${newExercise.name} added to your library');
      Navigator.of(context).pop(newExercise);
    } catch (e) {
      debugPrint('Could not save the exercise: $e');
      if (mounted) {
        AppSnack.show(context, ref, 'Could not save the exercise. Try again.',
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
    final existing = _existing;

    return AppScaffold(
      title: 'New exercise',
      bottomPadding: AppSpacing.xxxl,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Form(
          key: _formKey,
          child: FadeSlideIn(
            child: TextFormField(
              controller: _nameController,
              focusNode: _nameFocus,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              style: AppType.heading(t),
              decoration: InputDecoration(
                hintText: 'Exercise name',
                counterText: '',
                helperText: existing == null
                    ? null
                    : 'Already in your library under ${existing.category}',
                helperStyle: AppType.caption(t).copyWith(color: t.primary),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a name'
                  : null,
              onFieldSubmitted: (_) => _nameFocus.unfocus(),
            ),
          ),
        ),

        // An existing exercise keeps its own muscle group.
        if (existing == null) ...[
          const SizedBox(height: AppSpacing.xxl),
          const FadeSlideIn(index: 1, child: Overline('Muscle group')),
          FadeSlideIn(
            index: 1,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final category in exerciseCategories)
                  AppChip(
                    label: category,
                    selected: _selectedCategory == category,
                    onTap: () => _selectCategory(category),
                  ),
              ],
            ),
          ),
          if (_showCategoryError) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineError(message: 'Choose a muscle group', theme: t),
          ],
        ],
        const SizedBox(height: AppSpacing.xxxl),
        FadeSlideIn(
          index: 2,
          child: AppButton(
            label: existing == null ? 'Save exercise' : 'Use ${existing.name}',
            icon: Icons.check_rounded,
            expand: true,
            size: AppButtonSize.large,
            loading: _isLoading,
            onPressed: _isLoading ? null : _saveExercise,
          ),
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
        const SizedBox(width: AppSpacing.xs),
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
