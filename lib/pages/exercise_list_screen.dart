import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/master_exercise_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';
import 'create_exercise_screen.dart';

/// Step two of picking an exercise: the movements filed under one category.
///
/// Selecting a row pops it back to the category picker, which forwards it to
/// the workout builder.
class ExerciseListScreen extends ConsumerStatefulWidget {
  final String category;

  const ExerciseListScreen({super.key, required this.category});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Held in state so typing in the search box does not resubscribe the stream.
  late Stream<List<MasterExercise>> _stream;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _stream = _openStream();
  }

  Stream<List<MasterExercise>> _openStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return DatabaseService(uid: uid)
        .getMasterExercisesByCategory(widget.category);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() => _query = '');
  }

  List<MasterExercise> _filter(List<MasterExercise> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((exercise) => exercise.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _createExercise() async {
    _searchFocus.unfocus();

    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) => const CreateExerciseScreen(),
      ),
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    return AppScaffold(
      title: widget.category,
      subtitle: 'Pick an exercise',
      bottomPadding: AppSpacing.xxxl,
      actions: [
        AppIconButton(icon: Icons.add_rounded, onPressed: _createExercise),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: _SearchField(
              controller: _searchController,
              focusNode: _searchFocus,
              hintText: 'Search ${widget.category.toLowerCase()}',
              onChanged: (value) => setState(() => _query = value),
              onClear: _query.isEmpty ? null : _clearSearch,
            ),
          ),
        ),
        StreamBuilder<List<MasterExercise>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SkeletonBox(height: 76, radius: AppRadius.card),
                      SizedBox(height: AppSpacing.md),
                      SkeletonBox(height: 76, radius: AppRadius.card),
                      SizedBox(height: AppSpacing.md),
                      SkeletonBox(height: 76, radius: AppRadius.card),
                      SizedBox(height: AppSpacing.md),
                      SkeletonBox(height: 76, radius: AppRadius.card),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: 'Could not load the exercises.',
                  onRetry: () => setState(() => _stream = _openStream()),
                ),
              );
            }

            final all = snapshot.data ?? const <MasterExercise>[];

            if (all.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.fitness_center_rounded,
                  title: 'Nothing here yet',
                  message:
                      'No exercises are filed under ${widget.category} — add '
                      'the first one.',
                  actionLabel: 'Create exercise',
                  onAction: _createExercise,
                ),
              );
            }

            final exercises = _filter(all);

            if (exercises.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_rounded,
                  title: 'No matches',
                  message: 'Nothing in ${widget.category} matches "$_query".',
                  actionLabel: 'Clear search',
                  onAction: _clearSearch,
                ),
              );
            }

            return SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final exercise = exercises[index];
                    return FadeSlideIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppTile(
                          icon: Icons.fitness_center_rounded,
                          title: exercise.name,
                          iconColor: t.dataColor(index),
                          onTap: () => Navigator.of(context).pop(exercise),
                        ),
                      ),
                    );
                  },
                  childCount: exercises.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A small, self-contained search box that filters the list client-side.
class _SearchField extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppType.body(t),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.textTertiary),
        suffixIcon: onClear == null
            ? null
            : AppIconButton(
                icon: Icons.close_rounded,
                onPressed: onClear,
                filled: false,
                size: 36,
                iconSize: 18,
                color: t.textSecondary,
              ),
      ),
    );
  }
}
