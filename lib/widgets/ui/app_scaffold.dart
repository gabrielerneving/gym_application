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
        ambient: ambient,
      ),
    );
  }
}

/// The collapsing large-title header.
///
/// Two layouts:
///  * **Root pages** (no back chevron: the tabs): the large title sits right
///    under the status bar, on the same row as the actions. There is no empty
///    toolbar row above it.
///  * **Pushed pages**: a toolbar row with the back chevron and actions, the
///    large title under it.
///
/// Either way the large title moves 1:1 with the content and fades as it
/// goes; a compact inline title fades into the toolbar once it has gone.
///
/// Collapsed, the header is *the page itself*: it paints the page background
/// (and the same ambient glow, at the same screen position) instead of a
/// tinted or frosted band, and dissolves into the content over a soft fade
/// below its edge. Content scrolls away under it instead of being cut by a
/// hard line, and nothing gets blurred into coloured smudges.
class _LargeTitleHeader extends SliverPersistentHeaderDelegate {
  final AppColors theme;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback onBack;
  final double topInset;
  final Widget? bottom;
  final bool ambient;

  static const double _toolbarHeight = 52;

  /// Pushed pages: room for the large title under the toolbar row.
  static const double _largeTitleHeight = 62;

  /// Root pages: the title's line box starts this far below the status bar,
  /// which centres the title's caps on the toolbar row's actions.
  static const double _rootTitleTop = 7;

  /// Line box of [AppType.display] (34 x 1.1, rounded up).
  static const double _titleLine = 38;

  /// Air between the title block and the first piece of content.
  static const double _titleGap = AppSpacing.xl;

  static const double _bottomHeight = 58;

  /// The soft edge the collapsed header dissolves into, below its bounds.
  static const double _fadeHeight = 20;

  _LargeTitleHeader({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.showBack,
    required this.onBack,
    required this.topInset,
    required this.bottom,
    required this.ambient,
  });

  bool get _isRoot => !showBack;
  double get _subtitleHeight => subtitle == null ? 0 : 20;
  double get _bottomExtent => bottom == null ? 0 : _bottomHeight;

  @override
  double get minExtent => topInset + _toolbarHeight + _bottomExtent;

  @override
  double get maxExtent {
    if (_isRoot) {
      final expanded = topInset +
          _rootTitleTop +
          _titleLine +
          _subtitleHeight +
          _titleGap +
          _bottomExtent;
      return expanded < minExtent ? minExtent : expanded;
    }
    return topInset +
        _toolbarHeight +
        _largeTitleHeight +
        _subtitleHeight +
        _bottomExtent;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    // How far the content has moved, in px. Keeps growing past [range] while
    // the header itself stays pinned at [minExtent].
    final shift = shrinkOffset;

    final double largeOpacity;
    final double inlineOpacity;
    if (_isRoot) {
      // Fades over its own first ~18px of travel; the inline title takes over
      // once it is nearly gone.
      largeOpacity = (1 - shift / 18).clamp(0.0, 1.0);
      inlineOpacity = ((shift - 14) / 16).clamp(0.0, 1.0);
    } else {
      final tCollapse = (shift / range).clamp(0.0, 1.0);
      largeOpacity = (1 - tCollapse * 1.6).clamp(0.0, 1.0);
      inlineOpacity = ((tCollapse - 0.55) / 0.45).clamp(0.0, 1.0);
    }

    // The page-coloured fill fades in over the last 16px before content
    // starts passing under the header. It matches what is behind it, so the
    // ramp itself is invisible: only content disappearing under it shows.
    final fill = ((shift - (range - 16)) / 16).clamp(0.0, 1.0);

    final inlineTitle = Opacity(
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
    );

    final largeTitle = Opacity(
      opacity: largeOpacity,
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
    );

    final Widget toolbar;
    final Widget? largeTitleRegion;
    if (_isRoot) {
      // The large title shares the toolbar row: same width as the inline
      // title (so it never runs under the actions), overflowing downward,
      // clipped at the status bar as it travels up.
      toolbar = Row(
        children: [
          Expanded(
            child: ClipRect(
              clipper: const _ClipAboveOnly(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: inlineTitle,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _rootTitleTop - shift,
                    child: largeTitle,
                  ),
                ],
              ),
            ),
          ),
          ...actions,
        ],
      );
      largeTitleRegion = null;
    } else {
      toolbar = Row(
        children: [
          _BackChevron(theme: theme, onTap: onBack),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: inlineTitle),
          ...actions,
        ],
      );
      // Slides up under the toolbar row, 1:1 with the content.
      largeTitleRegion = ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: AppSpacing.screenH,
              right: AppSpacing.screenH,
              top: 2 - shift,
              child: largeTitle,
            ),
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        if (fill > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -_fadeHeight,
            child: IgnorePointer(
              child: Opacity(
                opacity: fill,
                child: _HeaderFill(
                  theme: theme,
                  ambient: ambient,
                  fadeHeight: _fadeHeight,
                ),
              ),
            ),
          ),
        if (largeTitleRegion != null)
          Positioned(
            left: 0,
            right: 0,
            top: topInset + _toolbarHeight,
            bottom: _bottomExtent,
            child: largeTitleRegion,
          ),
        Positioned(
          left: AppSpacing.screenH,
          right: AppSpacing.screenH,
          top: topInset,
          height: _toolbarHeight,
          child: toolbar,
        ),
        if (bottom != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
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
        old.ambient != ambient ||
        old.actions.length != actions.length;
  }
}

/// The collapsed header's background: the page colour plus the ambient glow
/// at exactly the position [AppScaffold] paints it behind the scroll view, so
/// the two are indistinguishable. Its last [fadeHeight] px fade to clear.
class _HeaderFill extends StatelessWidget {
  final AppColors theme;
  final bool ambient;
  final double fadeHeight;

  const _HeaderFill({
    required this.theme,
    required this.ambient,
    required this.fadeHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final solid = rect.height <= 0
            ? 0.0
            : ((rect.height - fadeHeight) / rect.height).clamp(0.0, 1.0);
        // Eased, not linear: content right under the edge stays mostly
        // hidden, then lets go quickly, so nothing ghosts below the toolbar.
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0xC7000000),
            Color(0x00000000),
          ],
          stops: [0.0, solid, solid + (1 - solid) * 0.45, 1.0],
        ).createShader(rect);
      },
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: theme.background)),
          if (ambient) AmbientBackground(theme: theme),
        ],
      ),
    );
  }
}

/// Clips only the top edge: lets the root large title (and its subtitle)
/// overflow the toolbar row downward, but not up into the status bar.
class _ClipAboveOnly extends CustomClipper<Rect> {
  const _ClipAboveOnly();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, 0, size.width * 2, size.height + 400);

  @override
  bool shouldReclip(covariant _ClipAboveOnly oldClipper) => false;
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
      // Same 42pt circle as AppIconButton, so a back chevron and the header
      // actions on the other side of the row read as one set.
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: theme.card,
          shape: BoxShape.circle,
          border: Border.all(color: theme.outline),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded,
            size: 17, color: theme.text),
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
