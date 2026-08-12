import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';

/// ---------------------------------------------------------------------------
/// Motion primitives.
///
/// Three ideas cover ~95% of the animation in the app:
///   * [FadeSlideIn]   — content arrives, staggered down a list.
///   * [Pressable]     — anything tappable dips slightly under the finger.
///   * [CountUp]       — numbers roll to their value instead of snapping.
/// ---------------------------------------------------------------------------

/// Fades and lifts its child into place once, on first build.
///
/// Pass [index] when rendering a list and the delay staggers automatically.
/// Delays stop growing after [AppMotion.maxStaggered] items so long lists never
/// feel like they are loading in slow motion.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration? delay;

  /// Distance in logical pixels the child travels while fading in.
  final double offsetY;
  final double offsetX;

  /// Set false to render immediately without animating (e.g. during tests or
  /// when the parent is already animating).
  final bool enabled;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = AppMotion.normal,
    this.delay,
    this.offsetY = 18,
    this.offsetX = 0,
    this.enabled = true,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    final stagger = widget.delay ??
        AppMotion.stagger *
            (widget.index.clamp(0, AppMotion.maxStaggered)).toDouble();
    if (stagger == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(stagger, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // `drive` rather than `CurvedAnimation`: the latter registers a status
  // listener on its parent in its constructor, so building one per frame
  // quietly accumulates listeners on the controller.
  late final Animation<double> _curved =
      _controller.drive(CurveTween(curve: AppMotion.enter));

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(widget.offsetX * (1 - t), widget.offsetY * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Wraps a tappable area so it scales down while pressed and fires haptics.
///
/// Prefer this over a bare `GestureDetector` — the tactile dip is what makes
/// the app feel responsive on a phone.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the widget shrinks while held. 0.97 is the house default; use a
  /// smaller dip (0.99) for very large surfaces and a bigger one (0.94) for
  /// small buttons.
  final double scale;

  final HapticStrength haptic;
  final BorderRadius? borderRadius;

  /// Draws a Material ink ripple on top of the scale. Off by default because
  /// the scale alone reads cleaner on cards.
  final bool ripple;
  final Color? rippleColor;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = HapticStrength.light,
    this.borderRadius,
    this.ripple = false,
    this.rippleColor,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

enum HapticStrength { none, selection, light, medium, heavy }

extension HapticStrengthX on HapticStrength {
  void fire() {
    switch (this) {
      case HapticStrength.none:
        break;
      case HapticStrength.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticStrength.light:
        HapticFeedback.lightImpact();
        break;
      case HapticStrength.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticStrength.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
  }
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setDown(bool value) {
    if (!_interactive || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedScale(
      scale: _down ? widget.scale : 1.0,
      duration: _down ? AppMotion.instant : AppMotion.fast,
      curve: AppMotion.standard,
      child: widget.child,
    );

    if (widget.ripple) {
      content = Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _interactive ? _handleTap : null,
          onLongPress: widget.onLongPress,
          borderRadius: widget.borderRadius,
          splashColor: widget.rippleColor,
          highlightColor: Colors.transparent,
          onTapDown: (_) => _setDown(true),
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          child: content,
        ),
      );
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _interactive ? _handleTap : null,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      child: content,
    );
  }

  void _handleTap() {
    widget.haptic.fire();
    widget.onTap?.call();
  }
}

/// Animates a number from its previous value to [value].
///
/// Use for anything that represents an accumulating quantity — total volume,
/// workout counts, streak days — so the screen feels alive when data lands.
class CountUp extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;

  /// Decimal places. 0 renders an integer.
  final int decimals;

  final String prefix;
  final String suffix;

  /// Optional custom formatter. Overrides [decimals]/[prefix]/[suffix].
  final String Function(double)? format;

  final TextAlign? textAlign;

  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = AppMotion.lazy,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.format,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: AppMotion.enter,
      builder: (context, v, _) {
        final text = format != null
            ? format!(v)
            : '$prefix${v.toStringAsFixed(decimals)}$suffix';
        return Text(text, style: style, textAlign: textAlign);
      },
    );
  }
}

/// Cross-fades and slides between two children when [value] changes.
/// Handy for figures that swap when a period filter changes.
class SwapTransitionBox extends StatelessWidget {
  final Object? value;
  final Widget child;
  final Duration duration;
  final Alignment alignment;

  const SwapTransitionBox({
    super.key,
    required this.value,
    required this.child,
    this.duration = AppMotion.normal,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.18),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

/// A slow, looping shimmer used by skeleton loaders.
class ShimmerBox extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final bool enabled;

  const ShimmerBox({
    super.key,
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    this.enabled = true,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.6 + t * 3.2, -0.4),
              end: Alignment(-0.6 + t * 3.2, 0.4),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
