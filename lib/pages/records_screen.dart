import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/ui/ui.dart';

/// How the record list is ordered.
enum _RecordSort { recent, heaviest, alphabetical }

/// ---------------------------------------------------------------------------
/// RecordsScreen — every all-time personal best, one card per exercise.
///
/// Reads [TrainingData.personalBests] (one [PersonalBest] per exercise) and
/// pairs each record with that lift's trend line, so you can see whether the
/// PR was a fluke or the top of a trend.
/// ---------------------------------------------------------------------------
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  final TextEditingController _searchController = TextEditingController();

  _RecordSort _sort = _RecordSort.recent;
  String _query = '';

  /// A record set inside this window is flagged as fresh.
  static const Duration _recentWindow = Duration(days: 30);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trainingDataProvider);

    return async.when(
      loading: () => _shell(body: const _RecordsSkeleton()),
      error: (error, _) => _shell(
        body: ErrorState(
          message: 'Could not load your records.',
          onRetry: () => ref.invalidate(workoutSessionsProvider),
        ),
      ),
      data: (data) {
        final records = data.personalBests;

        if (records.isEmpty) {
          return _shell(
            body: EmptyState(
              icon: Icons.emoji_events_rounded,
              title: 'No records yet',
              message:
                  'Log a few working sets and every exercise gets its own '
                  'personal best, estimated 1RM and trend line.',
              actionLabel: 'Reload',
              onAction: () => ref.invalidate(workoutSessionsProvider),
            ),
          );
        }

        final now = DateTime.now();
        // A record from an exercise's first session is a baseline, not news.
        bool isNew(PersonalBest r) =>
            !r.isDebut && now.difference(r.date) <= _recentWindow;
        final fresh = records.where(isNew).length;
        final visible = _applyFilters(records);

        return _shell(
          subtitle: '${records.length} '
              '${records.length == 1 ? 'exercise' : 'exercises'}'
              '${fresh > 0 ? ' · $fresh new in 30 days' : ''}',
          children: [
            const SizedBox(height: AppSpacing.sm),
            _SearchField(
              controller: _searchController,
              showClear: _query.isNotEmpty,
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            if (visible.isEmpty)
              EmptyState(
                icon: Icons.search_rounded,
                title: 'No matches',
                message: 'Nothing in your history matches "$_query".',
                actionLabel: 'Clear search',
                onAction: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              )
            else
              for (var i = 0; i < visible.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: FadeSlideIn(
                    index: i,
                    child: _RecordCard(
                      record: visible[i],
                      series: _trend(data.progressFor(visible[i].exercise)),
                      isNew: isNew(visible[i]),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  /// The page shell. Kept in one place so the loading, error, empty and content
  /// states all share the same header, sort control and pull-to-refresh.
  Widget _shell({String? subtitle, Widget? body, List<Widget>? children}) {
    return AppScaffold(
      title: 'Records',
      subtitle: subtitle,
      headerBottom: AppSegmented<_RecordSort>(
        value: _sort,
        segments: const [
          AppSegment(value: _RecordSort.recent, label: 'Recent'),
          AppSegment(value: _RecordSort.heaviest, label: 'Heaviest'),
          AppSegment(value: _RecordSort.alphabetical, label: 'A–Z'),
        ],
        onChanged: (value) => setState(() => _sort = value),
      ),
      onRefresh: () async {
        ref.invalidate(workoutSessionsProvider);
        try {
          await ref.read(trainingDataProvider.future);
        } catch (error) {
          debugPrint('Records refresh failed: $error');
        }
      },
      body: body,
      children: children,
    );
  }

  /// The line behind each record: estimated 1RM where there is one, the top
  /// weight for a lift only ever done for high reps, and the best set's reps
  /// for a bodyweight exercise.
  static List<double> _trend(ExerciseProgress progress) {
    if (progress.isBodyweight) {
      return [for (final p in progress.points) p.bestReps.toDouble()];
    }
    final oneRm = progress.oneRmSeries;
    if (oneRm.isNotEmpty) return oneRm;
    return [for (final p in progress.weightedPoints) p.topWeight];
  }

  List<PersonalBest> _applyFilters(List<PersonalBest> records) {
    final query = _query.trim().toLowerCase();
    final list = query.isEmpty
        ? List<PersonalBest>.from(records)
        : records
            .where((r) => r.exercise.toLowerCase().contains(query))
            .toList();

    if (_sort == _RecordSort.recent) {
      list.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sort == _RecordSort.heaviest) {
      list.sort((a, b) => b.weight.compareTo(a.weight));
    } else {
      list.sort(
        (a, b) => a.exercise.toLowerCase().compareTo(b.exercise.toLowerCase()),
      );
    }
    return list;
  }
}

/// A pill-shaped search field. The kit has no text input yet, so this is built
/// from tokens rather than raw values.
class _SearchField extends ConsumerWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: t.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19, color: t.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              style: AppType.body(t),
              cursorColor: t.primary,
              // The pill is the field: switch off the theme's own outline
              // and fill, which otherwise draw a second box inside it.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search exercises',
                hintStyle:
                    AppType.secondary(t).copyWith(color: t.textSecondary),
              ),
            ),
          ),
          if (showClear)
            Pressable(
              onTap: onClear,
              scale: 0.88,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: t.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One personal record: the best set ever logged for an exercise, its trend
/// line, and one line of context — estimated 1RM, when, and how often.
class _RecordCard extends ConsumerWidget {
  final PersonalBest record;

  /// The exercise's trend, oldest first.
  final List<double> series;

  /// Beat an earlier best inside the last 30 days.
  final bool isNew;

  const _RecordCard({
    required this.record,
    required this.series,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = isNew ? t.success : t.primary;

    final sessions =
        '${record.totalSessions} ${record.totalSessions == 1 ? 'session' : 'sessions'}';
    final details = [
      if (record.isBodyweight) 'Bodyweight',
      if (!record.isBodyweight && record.estimatedOneRm > 0)
        'e1RM ${AppFormat.weight(record.estimatedOneRm)} kg',
      AppFormat.relativeDate(record.date),
      sessions,
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg + 2,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.exercise,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.heading(t).copyWith(fontSize: 16),
                ),
              ),
              // A quiet marker rather than a pill: in a good month nearly
              // every card is new, and a row of badges stops saying anything.
              if (isNew) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.arrow_upward_rounded, size: 14, color: t.success),
                const SizedBox(width: 2),
                Text(
                  'New',
                  style: AppType.caption(t).copyWith(
                    color: t.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        record.isBodyweight
                            ? '${record.reps}'
                            : AppFormat.weight(record.weight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.metric(t, size: 28),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      record.isBodyweight
                          ? (record.reps == 1 ? 'rep' : 'reps')
                          : 'kg × ${record.reps}',
                      style: AppType.secondary(t),
                    ),
                  ],
                ),
              ),
              if (series.length > 1)
                SizedBox(
                  width: 88,
                  height: 32,
                  child: Sparkline(values: series, color: tone),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption(t),
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholders shaped like the record list.
class _RecordsSkeleton extends StatelessWidget {
  const _RecordsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.navBarClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(height: 48, radius: AppRadius.pill),
          SizedBox(height: AppSpacing.lg),
          SkeletonCard(height: 132),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 132),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 132),
        ],
      ),
    );
  }
}
