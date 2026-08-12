import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../theme/design_tokens.dart';
import 'floating_nav_bar.dart';
import 'motion.dart';

/// ---------------------------------------------------------------------------
/// AppScaffold — the page shell every screen uses.
///
/// Gives you, for free:
///   * an ambient colour wash behind the content,
///   * a large title that collapses into a frosted toolbar as you scroll,
///   * correct status-bar styling for the active palette,
///   * bottom padding that clears the floating nav bar,
///   * optional pull-to-refresh.
///
/// Supply either [children] (wrapped in a padded sliver list) or [slivers] for
/// full control.
///
/// ```dart
/// AppScaffold(
///   title: 'Statistics',
///   subtitle: 'Last 30 days',
///   actions: [AppIconButton(icon: Icons.settings, onPressed: ...)],
///   onRefresh: _load,
///   children: [ ... ],
/// )
/// ```
/// ---------------------------------------------------------------------------
class AppScaffold extends ConsumerWidget {
  final String title;
  final String? subtitle;

  /// Rendered to the right of the collapsed toolbar.
  final List<Widget> actions;

  /// Straight children, padded with the standard screen gutter.
  final List<Widget>? children;

  /// Raw slivers, if you need a grid or a sticky section.
  final List<Widget>? slivers;

  /// Pinned under the header — filter chips, a segmented control.
  final Widget? headerBottom;

  final Future<void> Function()? onRefresh;

  /// Shows a back chevron. Defaults to whatever the navigator can do.
  final bool? showBack;
  final VoidCallback? onBack;

  /// Extra bottom padding. Screens inside `MainScreen` should leave this at the
  /// default so content clears the floating nav bar.
  final double bottomPadding;

  /// Anchored above the nav bar, e.g. an [AppFab].
  final Widget? floatingAction;

  /// Replaces the whole scrolling body (loading and empty states).
  final Widget? body;

  /// Paints the soft primary glow behind the header. Disable on dense screens.
  final bool ambient;

  final ScrollController? scrollController;

  const AppScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.children,
    this.slivers,
    this.headerBottom,
    this.onRefresh,
    this.showBack,
    this.onBack,
    this.bottomPadding = AppSpacing.navBarClearance,
    this.floatingAction,
    this.body,
    this.ambient = true,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final canPop = showBack ?? Navigator.of(context).canPop();

    Widget content;
    if (body != null) {
      content = CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _header(context, t, canPop),
          SliverFillRemaining(hasScrollBody: false, child: body!),
        ],
      );
    } else {
      content = CustomScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _header(context, t, canPop),
          if (slivers != null) ...slivers!,
          if (children != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(children!),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: bottomPadding + MediaQuery.of(context).padding.bottom,
            ),
          ),
        ],
      );
    }

    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        color: t.primary,
        backgroundColor: t.card,
        displacement: 72,
        edgeOffset: MediaQuery.of(context).padding.top + 40,
        child: content,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppThemeData.systemOverlayStyle(t),
      child: Scaffold(
        backgroundColor: t.background,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            if (ambient) AmbientBackground(theme: t),
            content,
            if (floatingAction != null)
              Positioned(
                right: AppSpacing.screenH,
                bottom: MediaQuery.of(context).padding.bottom +
                    (bottomPadding > 0
                        ? NavBarMetrics.totalHeight + AppSpacing.md
                        : AppSpacing.xxl),
                child: FadeSlideIn(offsetY: 24, child: floatingAction!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppColors t, bool canPop) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeTitleHeader(
        theme: t,
        title: title,
        subtitle: subtitle,
        actions: actions,
        showBack: canPop,
        onBack: onBack ?? () => Navigator.of(context).maybePop(),
        topInset: MediaQuery.of(context).padding.top,
        bottom: headerBottom,
      ),
    );
  }
}

/// The collapsing large-title header.
///
/// Expanded: a big display title sitting under a compact toolbar row.
/// Collapsed: the toolbar row alone, frosted, with the title inline.
class _LargeTitleHeader extends SliverPersistentHeaderDelegate {
  final AppColors theme;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback onBack;
  final double topInset;
  final Widget? bottom;

  static const double _toolbarHeight = 52;
  static const double _largeTitleHeight = 62;
  static const double _bottomHeight = 58;

  _LargeTitleHeader({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.showBack,
    required this.onBack,
    required this.topInset,
    required this.bottom,
  });

  double get _subtitleHeight => subtitle == null ? 0 : 20;
  double get _bottomExtent => bottom == null ? 0 : _bottomHeight;

  @override
  double get minExtent => topInset + _toolbarHeight + _bottomExtent;

  @override
  double get maxExtent =>
      topInset + _toolbarHeight + _largeTitleHeight + _subtitleHeight + _bottomExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final tCollapse = (shrinkOffset / range).clamp(0.0, 1.0);

    // Large title fades out over the first 60% of the collapse.
    final largeOpacity = (1 - tCollapse * 1.6).clamp(0.0, 1.0);
    // Inline title fades in over the last 40%.
    final inlineOpacity = ((tCollapse - 0.55) / 0.45).clamp(0.0, 1.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18 * tCollapse,
          sigmaY: 18 * tCollapse,
        ),
        child: Container(
          color: theme.background.withValues(alpha: 0.62 * tCollapse),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: topInset),
              SizedBox(
                height: _toolbarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: Row(
                    children: [
                      if (showBack) ...[
                        _BackChevron(theme: theme, onTap: onBack),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Opacity(
                          opacity: inlineOpacity,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - inlineOpacity)),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.heading(theme).copyWith(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              ),
              // Large title — clipped away as the header collapses.
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minHeight: 0,
                    maxHeight: _largeTitleHeight + _subtitleHeight,
                    child: Opacity(
                      opacity: largeOpacity,
                      child: Transform.translate(
                        offset: Offset(-12 * tCollapse, -6 * tCollapse),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.screenH,
                            right: AppSpacing.screenH,
                            top: 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.display(theme),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.secondary(theme),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (bottom != null)
                SizedBox(
                  height: _bottomHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      0,
                      AppSpacing.screenH,
                      AppSpacing.md,
                    ),
                    child: bottom!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _LargeTitleHeader old) {
    return old.title != title ||
        old.subtitle != subtitle ||
        old.theme != theme ||
        old.showBack != showBack ||
        old.topInset != topInset ||
        old.bottom != bottom ||
        old.actions.length != actions.length;
  }
}

class _BackChevron extends StatelessWidget {
  final AppColors theme;
  final VoidCallback onTap;

  const _BackChevron({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.88,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: theme.card,
          shape: BoxShape.circle,
          border: Border.all(color: theme.outline),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded,
            size: 16, color: theme.text),
      ),
    );
  }
}

/// A soft radial wash of the primary colour behind the top of a page.
/// Purely decorative; it is what stops flat dark screens looking like a void.
class AmbientBackground extends StatelessWidget {
  final AppColors theme;
  final Alignment alignment;
  final double intensity;

  const AmbientBackground({
    super.key,
    required this.theme,
    this.alignment = Alignment.topRight,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -size.width * 0.42,
              right: alignment == Alignment.topRight ? -size.width * 0.25 : null,
              left: alignment == Alignment.topLeft ? -size.width * 0.25 : null,
              child: Container(
                width: size.width * 1.1,
                height: size.width * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.primary
                          .withValues(alpha: (theme.isDark ? 0.18 : 0.13) * intensity),
                      theme.primary.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -size.width * 0.16,
              left: -size.width * 0.34,
              child: Container(
                width: size.width * 0.85,
                height: size.width * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.accent
                          .withValues(alpha: (theme.isDark ? 0.10 : 0.08) * intensity),
                      theme.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plain page shell without the scrolling header — for full-bleed screens
/// (auth, active workout) that manage their own layout.
class AppPage extends ConsumerWidget {
  final Widget child;
  final bool ambient;
  final Color? background;
  final Widget? bottomBar;

  const AppPage({
    super.key,
    required this.child,
    this.ambient = true,
    this.background,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppThemeData.systemOverlayStyle(t),
      child: Scaffold(
        backgroundColor: background ?? t.background,
        extendBody: true,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: bottomBar,
        body: Stack(
          children: [
            if (ambient) AmbientBackground(theme: t),
            child,
          ],
        ),
      ),
    );
  }
}
