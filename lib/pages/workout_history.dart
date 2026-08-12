import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/workout_session_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/theme_provider.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../widgets/ui/ui.dart';
import '../widgets/workout_history_widget.dart';
import 'create_workout.dart';

/// The History tab.
///
/// Sessions stream live from Firestore, are grouped by calendar month and can
/// be filtered down to a single program. Swiping a row left deletes it after a
/// themed confirmation; the statistics cache is invalidated afterwards so every
/// other screen agrees with what is on screen here.
class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  static final DateFormat _monthFormat = DateFormat('MMMM yyyy');
  static final DateFormat _dayFormat = DateFormat('MMM d, yyyy');

  DatabaseService? _db;
  Stream<List<WorkoutSession>>? _sessions;

  /// The selected program filter, or null for "All".
  String? _programFilter;

  /// Ids hidden locally the moment a swipe completes, so the row leaves the
  /// list immediately instead of waiting for Firestore to echo the delete back.
  final Set<String> _removed = <String>{};

  /// Builds the stream once. Rebuilding [DatabaseService] on every build would
  /// resubscribe to Firestore every time a filter chip is tapped.
  Stream<List<WorkoutSession>>? _ensureStream() {
    if (_sessions != null) return _sessions;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final db = DatabaseService(uid: uid);
    _db = db;
    _sessions = db.getWorkoutSessions();
    return _sessions;
  }

  void _reload() {
    setState(() {
      _db = null;
      _sessions = null;
      _removed.clear();
    });
    ref.invalidate(workoutSessionsProvider);
  }

  Future<bool> _confirmDelete(WorkoutSession session) {
    return AppDialog.confirm(
      context: context,
      ref: ref,
      title: 'Delete workout?',
      message: '${session.programTitle} from '
          '${_dayFormat.format(session.date)} will be removed from your '
          'history and from your statistics. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
  }

  /// Hides the row, then deletes it for real.
  void _dismiss(WorkoutSession session) {
    setState(() => _removed.add(session.id));
    _deleteSession(session);
  }

  Future<void> _confirmAndDelete(WorkoutSession session) async {
    final confirmed = await _confirmDelete(session);
    if (!confirmed || !mounted) return;
    _dismiss(session);
  }

  Future<void> _deleteSession(WorkoutSession session) async {
    final db = _db;
    if (db == null) return;

    try {
      await db.deleteWorkoutSession(session.id);
      if (!mounted) return;
      // Keep every statistics screen in sync with the shortened history.
      ref.invalidate(workoutSessionsProvider);
      AppSnack.show(
        context,
        ref,
        'Workout deleted',
        icon: Icons.delete_outline_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      // Put the row back — the workout is still there.
      setState(() => _removed.remove(session.id));
      AppSnack.show(
        context,
        ref,
        'Could not delete the workout. Please try again.',
        isError: true,
      );
    }
  }

  void _openCreateWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateWorkoutScreen()),
    );
  }

  /// Distinct program titles, most used first.
  List<String> _programTitles(List<WorkoutSession> sessions) {
    final counts = <String, int>{};
    for (final session in sessions) {
      counts[session.programTitle] = (counts[session.programTitle] ?? 0) + 1;
    }
    final titles = counts.keys.toList();
    titles.sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return titles;
  }

  List<_MonthGroup> _groupByMonth(List<WorkoutSession> sessions) {
    final ordered = [...sessions]..sort((a, b) => b.date.compareTo(a.date));
    final groups = <_MonthGroup>[];
    for (final session in ordered) {
      final month = DateTime(session.date.year, session.date.month);
      if (groups.isEmpty || groups.last.month != month) {
        groups.add(_MonthGroup(month));
      }
      groups.last.add(session);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _ensureStream();

    if (stream == null) {
      return const AppScaffold(
        title: 'History',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not signed in',
          message: 'Sign in to see your training history.',
        ),
      );
    }

    return StreamBuilder<List<WorkoutSession>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppScaffold(
            title: 'History',
            body: ErrorState(
              message: 'Could not load your workout history.',
              onRetry: _reload,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const AppScaffold(
            title: 'History',
            subtitle: 'Loading your sessions…',
            body: _HistorySkeleton(),
          );
        }

        final all = snapshot.data!
            .where((session) => !_removed.contains(session.id))
            .toList();

        if (all.isEmpty) {
          return AppScaffold(
            title: 'History',
            subtitle: 'No sessions yet',
            body: EmptyState(
              icon: Icons.history_rounded,
              title: 'Your history is empty',
              message: 'Finish a workout and it shows up here with its '
                  'volume, sets and heaviest lift.',
              actionLabel: 'Create a workout',
              onAction: _openCreateWorkout,
            ),
          );
        }

        final titles = _programTitles(all);
        final filter =
            _programFilter != null && titles.contains(_programFilter)
                ? _programFilter
                : null;

        final visible = filter == null
            ? all
            : all.where((session) => session.programTitle == filter).toList();

        final filterRow = titles.length > 1
            ? _ProgramFilterRow(
                titles: titles,
                selected: filter,
                onChanged: (value) =>
                    setState(() => _programFilter = value),
              )
            : null;

        if (visible.isEmpty) {
          return AppScaffold(
            title: 'History',
            subtitle: 'No sessions for ${filter ?? 'this filter'}',
            headerBottom: filterRow,
            body: EmptyState(
              icon: Icons.filter_list_rounded,
              title: 'Nothing here',
              message: 'You have no sessions left for this program.',
              actionLabel: 'Show all sessions',
              onAction: () => setState(() => _programFilter = null),
            ),
          );
        }

        final rows = <_HistoryRow>[];
        var animationIndex = 0;
        for (final group in _groupByMonth(visible)) {
          rows.add(_MonthRow(group));
          for (final session in group.sessions) {
            rows.add(_SessionRow(session: session, index: animationIndex++));
          }
        }

        final subtitle = filter == null
            ? '${all.length} ${all.length == 1 ? 'session' : 'sessions'}'
            : '${visible.length} of ${all.length} sessions · $filter';

        return AppScaffold(
          title: 'History',
          subtitle: subtitle,
          headerBottom: filterRow,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildRow(rows[index]),
                  childCount: rows.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(_HistoryRow row) {
    if (row is _MonthRow) {
      return _MonthHeader(
        group: row.group,
        label: _monthFormat.format(row.group.month),
      );
    }

    final sessionRow = row as _SessionRow;
    final session = sessionRow.session;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Dismissible(
        key: ValueKey<String>('history-${session.id}'),
        direction: DismissDirection.endToStart,
        background: const _DeleteBackground(),
        confirmDismiss: (_) => _confirmDelete(session),
        onDismissed: (_) => _dismiss(session),
        child: FadeSlideIn(
          index: sessionRow.index,
          child: WorkoutHistoryWidget(
            session: session,
            onDelete: () {
              _confirmAndDelete(session);
            },
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Rows
/// ---------------------------------------------------------------------------

/// One entry in the flattened list: either a month header or a session.
abstract class _HistoryRow {
  const _HistoryRow();
}

class _MonthRow extends _HistoryRow {
  final _MonthGroup group;

  const _MonthRow(this.group);
}

class _SessionRow extends _HistoryRow {
  final WorkoutSession session;

  /// Position among the sessions only, so the entrance stagger is not thrown
  /// off by the month headers.
  final int index;

  const _SessionRow({required this.session, required this.index});
}

/// The sessions of one calendar month, with their combined tonnage.
class _MonthGroup {
  final DateTime month;
  final List<WorkoutSession> sessions = <WorkoutSession>[];
  double volume = 0;

  _MonthGroup(this.month);

  void add(WorkoutSession session) {
    sessions.add(session);
    volume += AnalyticsService.sessionVolume(session);
  }
}

class _MonthHeader extends StatelessWidget {
  final _MonthGroup group;
  final String label;

  const _MonthHeader({required this.group, required this.label});

  @override
  Widget build(BuildContext context) {
    final count = group.sessions.length;
    return SectionHeader(
      title: label,
      subtitle: '$count ${count == 1 ? 'session' : 'sessions'} · '
          '${AppFormat.compact(group.volume)} kg',
      icon: Icons.calendar_month_rounded,
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.md,
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Chrome
/// ---------------------------------------------------------------------------

/// The pinned program filter under the title.
class _ProgramFilterRow extends StatelessWidget {
  final List<String> titles;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ProgramFilterRow({
    required this.titles,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: titles.length + 1,
      separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Center(
            child: AppChip(
              label: 'All',
              icon: Icons.all_inclusive_rounded,
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
          );
        }

        final title = titles[index - 1];
        return Center(
          child: AppChip(
            label: title,
            selected: selected == title,
            onTap: () => onChanged(selected == title ? null : title),
          ),
        );
      },
    );
  }
}

/// Revealed while swiping a session away.
class _DeleteBackground extends ConsumerWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: t.error.withValues(alpha: t.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete',
            style: AppType.button(t).copyWith(color: t.error, fontSize: 14),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.delete_outline_rounded, size: 20, color: t.error),
        ],
      ),
    );
  }
}

/// Shimmering placeholders shaped like a month of sessions.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 160, height: 20),
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
