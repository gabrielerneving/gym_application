import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/master_exercise_model.dart';
import '../providers/theme_provider.dart';
import '../widgets/ui/ui.dart';
import 'create_exercise_screen.dart';
import 'exercise_list_screen.dart';

/// Step one of picking an exercise: search the whole library, or browse it by
/// muscle group.
///
/// Pops the chosen `MasterExercise` all the way back to the caller, so the
/// workout builder (and the active workout's "Add exercise") only ever sees
/// one result.
class ChooseCategoryScreen extends ConsumerStatefulWidget {
  const ChooseCategoryScreen({super.key});

  /// The categories exercises are filed under — see [exerciseCategories].
  final List<String> categories = exerciseCategories;

  @override
  ConsumerState<ChooseCategoryScreen> createState() =>
      _ChooseCategoryScreenState();
}

class _ChooseCategoryScreenState extends ConsumerState<ChooseCategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// The whole library, held in state so typing does not resubscribe.
  late Stream<List<MasterExercise>> _library;

  String _query = '';

  bool get _isSearching => _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _library = _openLibrary();
  }

  Stream<List<MasterExercise>> _openLibrary() =>
      watchExerciseLibrary(FirebaseAuth.instance.currentUser!.uid);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Every word has to appear somewhere in the name ("inc press" finds
  /// "Incline dumbbell press"); names that start with the query rank first.
  List<MasterExercise> _search(List<MasterExercise> library) {
    final q = _query.trim().toLowerCase();
    final words = q.split(RegExp(r'\s+'));

    final hits = library.where((exercise) {
      final name = exercise.name.toLowerCase();
      return words.every(name.contains);
    }).toList();

    hits.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      final aRank = aName.startsWith(q) ? 0 : 1;
      final bRank = bName.startsWith(q) ? 0 : 1;
      if (aRank != bRank) return aRank - bRank;
      return aName.compareTo(bName);
    });
    return hits;
  }

  void _pick(MasterExercise exercise) => Navigator.of(context).pop(exercise);

  Future<void> _openCategory(String category) async {
    _searchFocus.unfocus();
    final selectedExercise = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) => ExerciseListScreen(category: category),
      ),
    );

    if (selectedExercise != null && mounted) {
      Navigator.of(context).pop(selectedExercise);
    }
  }

  Future<void> _createExercise() async {
    _searchFocus.unfocus();
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (context) => const CreateExerciseScreen(),
      ),
    );

    // A freshly created exercise goes straight back to the caller.
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    return AppScaffold(
      title: 'Add exercise',
      bottomPadding: AppSpacing.xxxl,
      actions: [
        AppIconButton(
          icon: Icons.add_rounded,
          tooltip: 'New exercise',
          onPressed: _createExercise,
        ),
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
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              style: AppType.body(t),
              decoration: InputDecoration(
                hintText: 'Search your exercises',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: t.textTertiary,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : AppIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Clear',
                        onPressed: _clearSearch,
                        filled: false,
                        size: 36,
                        iconSize: 18,
                        color: t.textSecondary,
                      ),
              ),
            ),
          ),
        ),
        StreamBuilder<List<MasterExercise>>(
          stream: _library,
          builder: (context, snapshot) {
            final library = snapshot.data;

            if (!_isSearching) {
              return _categoryGrid(library);
            }

            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: 'Could not search your exercises.',
                  onRetry: () => setState(() => _library = _openLibrary()),
                ),
              );
            }

            if (library == null) {
              return const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                sliver: SliverToBoxAdapter(child: ExercisePickerSkeleton()),
              );
            }

            final matches = _search(library);
            if (matches.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_rounded,
                  title: 'No matches',
                  message: 'Nothing in your library matches "${_query.trim()}".',
                  actionLabel: 'New exercise',
                  onAction: _createExercise,
                ),
              );
            }

            return SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExercisePickerList(
                      exercises: matches,
                      showCategory: true,
                      onPick: _pick,
                    ),
                    NewExerciseHint(onTap: _createExercise),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Two columns of muscle groups, each with its exercise count once the
  /// library has loaded.
  Widget _categoryGrid(List<MasterExercise>? library) {
    final counts = <String, int>{};
    for (final exercise in library ?? const <MasterExercise>[]) {
      counts[exercise.category] = (counts[exercise.category] ?? 0) + 1;
    }

    final categories = widget.categories;
    final rowCount = (categories.length / 2).ceil();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, row) {
            Widget cell(int index) {
              if (index >= categories.length) return const SizedBox.shrink();
              final category = categories[index];
              return FadeSlideIn(
                index: index,
                child: _CategoryCard(
                  label: category,
                  count: library == null ? null : (counts[category] ?? 0),
                  onTap: () => _openCategory(category),
                ),
              );
            }

            if (row == rowCount) {
              return NewExerciseHint(onTap: _createExercise);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(child: cell(row * 2)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: cell(row * 2 + 1)),
                ],
              ),
            );
          },
          childCount: rowCount + 1,
        ),
      ),
    );
  }
}

/// One tappable muscle-group tile.
class _CategoryCard extends ConsumerWidget {
  final String label;

  /// Null while the library is still loading.
  final int? count;

  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final n = count;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.heading(t),
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Always laid out, so the tile does not grow when the count lands.
          Text(
            switch (n) {
              null => ' ',
              0 => 'None yet',
              1 => '1 exercise',
              _ => '$n exercises',
            },
            maxLines: 1,
            style: n == 0
                ? AppType.secondary(t).copyWith(color: t.textTertiary)
                : AppType.secondary(t),
          ),
        ],
      ),
    );
  }
}
