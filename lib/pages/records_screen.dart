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
/// pairs each record with the estimated-1RM curve for that lift so you can see
/// whether the PR was a fluke or the top of a trend.
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
        final fresh = records
            .where((r) => now.difference(r.date) <= _recentWindow)
            .length;
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
                      series: data.progressFor(visible[i].exercise).oneRmSeries,
                      isNew: now.difference(visible[i].date) <= _recentWindow,
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
              decoration: InputDecoration.collapsed(
                hintText: 'Search exercises',
                hintStyle:
                    AppType.secondary(t).copyWith(color: t.textTertiary),
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

/// One personal record: the heaviest working set ever logged for an exercise,
/// what it estimates as a 1RM, when it happened and how the lift has trended.
class _RecordCard extends ConsumerWidget {
  final PersonalBest record;

  /// Estimated 1RM per session for this exercise, oldest first.
  final List<double> series;

  /// Set inside the last 30 days.
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.emoji_events_rounded,
                color: tone,
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  record.exercise,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.heading(t).copyWith(fontSize: 16),
                ),
              ),
              if (isNew) ...[
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: 'New',
                  color: t.success,
                  icon: Icons.bolt_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Overline('Best set'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            AppFormat.weight(record.weight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.metric(t, size: 26),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'kg × ${record.reps}',
                          style: AppType.secondary(t),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (series.length > 1)
                SizedBox(
                  width: 92,
                  height: 42,
                  child: Sparkline(values: series, color: tone),
                ),
            ],
          ),
          Divider(height: AppSpacing.xxl, thickness: 1, color: t.divider),
          MetricRow(
            label: 'Estimated 1RM',
            value: '${AppFormat.weight(record.estimatedOneRm)} kg',
            icon: Icons.trending_up_rounded,
            valueColor: tone,
          ),
          MetricRow(
            label: 'Record set',
            value: AppFormat.relativeDate(record.date),
            icon: Icons.event_available_rounded,
          ),
          MetricRow(
            label: 'Last performed',
            value: AppFormat.relativeDate(record.lastPerformed),
            icon: Icons.history_rounded,
          ),
          MetricRow(
            label: 'Sessions logged',
            value: '${record.totalSessions}',
            icon: Icons.repeat_rounded,
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
          SkeletonCard(height: 210),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 210),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(height: 210),
        ],
      ),
    );
  }
}
