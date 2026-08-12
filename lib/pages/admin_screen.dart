import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/admin_config.dart';
import '../providers/theme_provider.dart';
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
  bool _isLoading = false;
  String _status = '';

  bool get _statusIsError => _status.contains('Error');

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeProvider);

    // Security check - only allow admin users
    if (!_isAdminUser()) {
      return const AppScaffold(
        title: 'Access Denied',
        ambient: false,
        body: _AccessDenied(),
      );
    }

    return AppScaffold(
      title: 'Admin Panel',
      subtitle: 'Internal tools',
      bottomPadding: AppSpacing.huge,
      children: [
        const FadeSlideIn(
          index: 0,
          child: SectionHeader(
            title: 'Template Management',
            subtitle: 'Add standard workout templates for all users',
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.md,
            ),
          ),
        ),

        FadeSlideIn(
          index: 1,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const IconBadge(icon: Icons.playlist_add_rounded),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        'Add Sample Templates',
                        style: AppType.heading(t),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'This will add 4 awesome workout templates:\n'
                  '• Upper Body Workout (60 min)\n'
                  '• Legs Focus Workout (70 min)\n'
                  '• Push Day Workout (65 min)\n'
                  '• Pull Day Workout (65 min)',
                  style: AppType.secondary(t).copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _isLoading
                      ? 'Adding templates…'
                      : 'Add Sample Templates',
                  onPressed: _isLoading ? null : _addSampleTemplates,
                  loading: _isLoading,
                  expand: true,
                  icon: Icons.add_circle_outline_rounded,
                ),
              ],
            ),
          ),
        ),

        if (_status.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 2,
            child: _StatusBanner(message: _status, isError: _statusIsError),
          ),
        ],

        const SizedBox(height: AppSpacing.xxl),

        FadeSlideIn(
          index: 3,
          child: AppCard(
            color: t.warning.withValues(alpha: t.isDark ? 0.12 : 0.08),
            border: Border.all(color: t.warning.withValues(alpha: 0.30)),
            shadow: const [],
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: t.warning),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Warning: Only add templates once! Duplicate templates '
                    'will create multiple entries in the database.',
                    style: AppType.caption(t).copyWith(
                      color: t.warning,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addSampleTemplates() async {
    setState(() {
      _isLoading = true;
      _status = '';
    });

    try {
      await addSampleTemplates();
      if (!mounted) return;
      setState(() {
        _status = 'Successfully added 4 awesome workout templates!';
        _isLoading = false;
      });
      AppSnack.show(context, ref, 'Templates added');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error adding templates: $e';
        _isLoading = false;
      });
      AppSnack.show(context, ref, 'Could not add templates', isError: true);
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

/// The result of the last run, kept on screen so the outcome does not vanish
/// with the snack bar.
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
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      t.error.withValues(alpha: t.isDark ? 0.22 : 0.14),
                      t.error.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Icon(Icons.lock_rounded, size: 34, color: t.error),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Admin Access Required',
                textAlign: TextAlign.center,
                style: AppType.title(t),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You do not have permission to access this page.',
                textAlign: TextAlign.center,
                style: AppType.secondary(t).copyWith(fontSize: 14.5),
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
