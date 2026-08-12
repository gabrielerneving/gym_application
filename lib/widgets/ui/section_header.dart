import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/design_tokens.dart';
import 'motion.dart';

/// A titled divider between groups of content.
///
/// ```dart
/// SectionHeader(title: 'This week', action: 'See all', onAction: ...)
/// ```
class SectionHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;

  /// Text of the trailing link.
  final String? action;
  final VoidCallback? onAction;

  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.icon,
    this.padding = const EdgeInsets.only(
      top: AppSpacing.xxl,
      bottom: AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: t.primary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppType.title(t).copyWith(fontSize: 19)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppType.secondary(t)),
                ],
              ],
            ),
          ),
          if (action != null && onAction != null)
            Pressable(
              onTap: onAction,
              scale: 0.94,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action!,
                      style: AppType.secondary(t).copyWith(
                        color: t.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 17, color: t.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An all-caps eyebrow used above dense groups inside a card.
class Overline extends ConsumerWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const Overline(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return Padding(
      padding: padding,
      child: Text(text.toUpperCase(), style: AppType.overline(t)),
    );
  }
}
