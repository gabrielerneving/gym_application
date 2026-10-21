import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/admin_config.dart';
import '../models/standard_workout_template.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../utils/add_sample_templates.dart';
import '../widgets/ui/ui.dart';

/// ---------------------------------------------------------------------------
/// Internal admin tooling. Gated on [AdminConfig.isAdminEmail]; everybody else
/// gets a locked page.
/// ---------------------------------------------------------------------------
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  late final Stream<List<StandardWorkoutTemplate>> _templates =
      StandardWorkoutService.getStandardWorkouts();

  bool _isLoading = false;
  String _status = '';
  bool _statusIsError = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    // Security check - only allow admin users
    if (!_isAdminUser()) {
      return const AppScaffold(
        title: 'Access denied',
        ambient: false,
        body: _AccessDenied(),
      );
    }

    return AppScaffold(
      title: 'Admin',
      bottomPadding: AppSpacing.huge,
      children: [
        const FadeSlideIn(
          index: 0,
          child: SectionHeader(
            title: 'Templates',
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.md,
            ),
          ),
        ),
        FadeSlideIn(
          index: 1,
          child: StreamBuilder<List<StandardWorkoutTemplate>>(
            stream: _templates,
            builder: (context, snapshot) {
              final live = snapshot.data?.length;

              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sample templates', style: AppType.heading(t)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Upper Body, Legs Focus, Push Day and Pull Day — '
                      'visible to every user.',
                      style: AppType.secondary(t),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MetricRow(
                      label: 'Templates live now',
                      value: live == null ? '–' : '$live',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Add sample templates',
                      onPressed: _isLoading
                          ? null
                          : () => _addSampleTemplates(alreadyLive: live ?? 0),
                      loading: _isLoading,
                      expand: true,
                      icon: Icons.add_rounded,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 2,
            child: _StatusBanner(message: _status, isError: _statusIsError),
          ),
        ],
      ],
    );
  }

  Future<void> _addSampleTemplates({required int alreadyLive}) async {
    // Adding twice writes every template twice — make that a choice.
    if (alreadyLive > 0) {
      final proceed = await AppDialog.confirm(
        context: context,
        ref: ref,
        title: 'Add them again?',
        message: '$alreadyLive templates are already live. Adding the samples '
            'again creates duplicates for every user.',
        confirmLabel: 'Add anyway',
        destructive: true,
      );
      if (!proceed || !mounted) return;
    }

    setState(() {
      _isLoading = true;
      _status = '';
    });

    try {
      await addSampleTemplates();
      if (!mounted) return;
      setState(() {
        _status = 'Added the 4 sample templates.';
        _statusIsError = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Could not add templates: $e';
        _statusIsError = true;
        _isLoading = false;
      });
    }
  }

  // Check if current user has admin privileges
  bool _isAdminUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Använd säker config-fil för admin emails
    return AdminConfig.isAdminEmail(user.email ?? '');
  }
}

/// The result of the last run, kept on screen so the outcome does not vanish.
class _StatusBanner extends ConsumerWidget {
  final String message;
  final bool isError;

  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = isError ? t.error : t.success;

    return AppCard(
      color: tone.withValues(alpha: t.isDark ? 0.14 : 0.09),
      border: Border.all(color: tone.withValues(alpha: 0.30)),
      shadow: const [],
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 20,
            color: tone,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppType.secondary(t).copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown to anybody who is not on the admin list.
class _AccessDenied extends ConsumerWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 34, color: t.textTertiary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Admins only',
                textAlign: TextAlign.center,
                style: AppType.title(t),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton.outline(
                label: 'Go back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icons.arrow_back_rounded,
                size: AppButtonSize.small,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
