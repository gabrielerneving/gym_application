import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import 'app_buttons.dart';
import 'app_card.dart';
import 'feedback.dart';
import 'motion.dart';

/// ---------------------------------------------------------------------------
/// Modal surfaces: bottom sheets, dialogs and action menus.
///
/// Every modal in the app goes through here so they share one look — a drag
/// handle, a 32px top radius, hairline border and blurred scrim.
/// ---------------------------------------------------------------------------
class AppSheet {
  AppSheet._();

  /// Shows a themed bottom sheet.
  ///
  /// ```dart
  /// await AppSheet.show<void>(
  ///   context: context,
  ///   ref: ref,
  ///   title: 'Pick an exercise',
  ///   builder: (context) => ...,
  /// );
  /// ```
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetRef ref,
    required WidgetBuilder builder,
    String? title,
    String? subtitle,
    bool isScrollControlled = true,

    /// Fraction of the screen the sheet may occupy.
    double maxHeightFactor = 0.86,
    bool showHandle = true,
    EdgeInsetsGeometry? padding,
  }) {
    final t = ref.read(themeProvider);

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: t.scrim,
      elevation: 0,
      useSafeArea: true,
      builder: (context) {
        return _SheetShell(
          theme: t,
          title: title,
          subtitle: subtitle,
          showHandle: showHandle,
          maxHeightFactor: maxHeightFactor,
          padding: padding,
          child: Builder(builder: builder),
        );
      },
    );
  }

  /// A list of actions in a sheet — the replacement for the long-press menu.
  /// [subtitle] sits under the title ("Set 3" / "Bench Press").
  static Future<void> actions({
    required BuildContext context,
    required WidgetRef ref,
    required List<SheetAction> actions,
    String? title,
    String? subtitle,
  }) {
    return show<void>(
      context: context,
      ref: ref,
      title: title,
      subtitle: subtitle,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++)
              FadeSlideIn(
                index: i,
                offsetY: 10,
                child: _SheetActionRow(action: actions[i]),
              ),
          ],
        );
      },
    );
  }
}

class SheetAction {
  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final bool destructive;

  const SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.destructive = false,
  });
}

class _SheetActionRow extends ConsumerWidget {
  final SheetAction action;

  const _SheetActionRow({required this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final tone = action.destructive ? t.error : t.text;

    return Pressable(
      scale: 0.98,
      onTap: () {
        Navigator.of(context).pop();
        action.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            // Neutral for ordinary actions; only a destructive row carries
            // colour, so it stands out by more than its label.
            IconBadge(
              icon: action.icon,
              color: action.destructive ? t.error : null,
              neutral: true,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.label,
                    style: AppType.body(t).copyWith(
                      color: tone,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (action.description != null) ...[
                    const SizedBox(height: 2),
                    Text(action.description!, style: AppType.secondary(t)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title style of a sheet — 19pt bold. Exposed so a sheet that draws its
/// own header (a picker with a search field) can match the shell.
TextStyle sheetTitleStyle(AppColors t) =>
    AppType.heading(t).copyWith(fontSize: 19, letterSpacing: -0.3);

class _SheetShell extends StatelessWidget {
  final AppColors theme;
  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showHandle;
  final double maxHeightFactor;
  final EdgeInsetsGeometry? padding;

  const _SheetShell({
    required this.theme,
    required this.child,
    required this.title,
    required this.subtitle,
    required this.showHandle,
    required this.maxHeightFactor,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * maxHeightFactor,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.elevated,
          borderRadius: AppRadius.sheetTop,
          border: Border(
            top: BorderSide(color: theme.outline),
            left: BorderSide(color: theme.outline),
            right: BorderSide(color: theme.outline),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A sheet title labels the sheet; it is not a page
                    // headline, so it stays a step under AppType.title.
                    SizedBox(
                      width: double.infinity,
                      child: Text(title!, style: sheetTitleStyle(theme)),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle!, style: AppType.secondary(theme)),
                    ],
                  ],
                ),
              ),
            Flexible(
              child: Padding(
                padding: padding ??
                    EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      title != null ? AppSpacing.lg : AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.lg + media.padding.bottom,
                    ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Dialogs.
/// ---------------------------------------------------------------------------
class AppDialog {
  AppDialog._();

  /// A yes/no confirmation. Returns true when the user confirms.
  ///
  /// ```dart
  /// final ok = await AppDialog.confirm(
  ///   context: context, ref: ref,
  ///   title: 'Delete workout?',
  ///   message: 'This cannot be undone.',
  ///   confirmLabel: 'Delete',
  ///   destructive: true,
  /// );
  /// ```
  static Future<bool> confirm({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await show<bool>(
      context: context,
      ref: ref,
      title: title,
      message: message,
      icon: icon ??
          (destructive
              ? Icons.warning_amber_rounded
              : Icons.help_outline_rounded),
      iconColor: destructive ? ref.read(themeProvider).error : null,
      actionsBuilder: (context, t) => [
        Expanded(
          child: AppButton.secondary(
            label: cancelLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: destructive
              ? AppButton.danger(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                )
              : AppButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
        ),
      ],
    );
    return result ?? false;
  }

  /// An informational dialog with a single dismiss button.
  static Future<void> info({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    String? message,
    String buttonLabel = 'Got it',
    IconData? icon,
  }) {
    return show<void>(
      context: context,
      ref: ref,
      title: title,
      message: message,
      icon: icon ?? Icons.info_outline_rounded,
      actionsBuilder: (context, t) => [
        Expanded(
          child: AppButton(
            label: buttonLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  /// The general form. [content] renders between the message and the actions.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    String? message,
    Widget? content,
    IconData? icon,
    Color? iconColor,
    List<Widget> Function(BuildContext context, AppColors theme)? actionsBuilder,
    bool barrierDismissible = true,
  }) {
    final t = ref.read(themeProvider);
    HapticFeedback.lightImpact();

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: title,
      barrierColor: t.scrim,
      transitionDuration: AppMotion.fast,
      pageBuilder: (context, _, __) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, __) {
        // `drive`, not `CurvedAnimation` — the latter attaches a status
        // listener to its parent every time this builder runs.
        final curved = animation.drive(CurveTween(curve: AppMotion.spring));
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.92 + 0.08 * curved.value.clamp(0.0, 1.2),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: t.elevated,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: t.outline),
                        boxShadow: t.shadowFloating,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (icon != null) ...[
                            Center(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: (iconColor ?? t.primary)
                                      .withValues(alpha: t.isDark ? 0.16 : 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon,
                                    color: iconColor ?? t.primary, size: 25),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          BalancedText(
                            title,
                            textAlign: TextAlign.center,
                            style: AppType.title(t).copyWith(fontSize: 20),
                          ),
                          if (message != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            BalancedText(
                              message,
                              textAlign: TextAlign.center,
                              style: AppType.secondary(t)
                                  .copyWith(fontSize: 14.5, height: 1.45),
                            ),
                          ],
                          if (content != null) ...[
                            const SizedBox(height: AppSpacing.xl),
                            content,
                          ],
                          if (actionsBuilder != null) ...[
                            const SizedBox(height: AppSpacing.xxl),
                            Row(children: actionsBuilder(context, t)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
