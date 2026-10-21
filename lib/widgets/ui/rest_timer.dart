import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/rest_timer_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import 'app_card.dart';
import 'app_chips.dart';
import 'app_sheet.dart';
import 'motion.dart';

/// ---------------------------------------------------------------------------
/// The floating rest timer.
///
/// Sits at the bottom of the active workout screen, where a thumb can reach it
/// without looking. Idle it is a small "Rest" pill; running it shows a
/// progress ring and the elapsed time, and breathes once the target is passed.
///
/// Tap to start/stop. While idle the trailing button opens the target picker;
/// while running it restarts the rest. Long-press opens the picker any time.
/// ---------------------------------------------------------------------------
class RestTimerBar extends ConsumerWidget {
  /// Extra bottom inset, e.g. to clear a floating nav bar.
  final double bottomPadding;

  const RestTimerBar({super.key, this.bottomPadding = 0});

  /// Gap between the pill and the bottom safe area — low, where the thumb
  /// rests, and out of the middle of the list.
  static const double _bottomGap = AppSpacing.sm;

  /// How far above the pill the fade behind it reaches.
  static const double _fade = AppSpacing.xl;

  /// Vertical space the bar and its fade occupy above the bottom safe area
  /// (excluding [bottomPadding]) — what scrolling content needs to stay
  /// clear of to be fully readable.
  static const double clearance = RestTimerPill.height + _bottomGap + _fade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final below = bottomInset + bottomPadding + _bottomGap;
    final fadeHeight = _fade + RestTimerPill.height + below;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The list fades into the page behind the pill, so the rows under it
        // slide out of view instead of being cut in half by a floating chip
        // sitting on top of their inputs. Taps pass straight through.
        Positioned(
          left: 0,
          right: 0,
          top: -_fade,
          bottom: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    t.background.withValues(alpha: 0),
                    t.background.withValues(alpha: 0.9),
                    t.background,
                  ],
                  stops: [
                    0,
                    _fade / fadeHeight,
                    (_fade + RestTimerPill.height / 2) / fadeHeight,
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: below,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
          ),
          // A Row, not Align/Center: those expand to the tallest allowed
          // height when the parent leaves the vertical axis loose, which would
          // stretch the pill's box over the whole screen. A Row shrink-wraps.
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [RestTimerPill()],
          ),
        ),
      ],
    );
  }
}

/// Buzzes once when a running rest reaches its target — a double heavy tap,
/// so the end of a rest is felt with the phone in a pocket or face down on
/// the bench, where the pill's visual pulse is useless.
///
/// Wrap the whole screen that shows the rest timer with it rather than relying
/// on the pill: the pill is hidden while the keyboard is up, the buzz should
/// not be. It fires on the tick that crosses the target only, so rebuilds never
/// repeat it, and a new rest (which starts below the target) re-arms it.
class RestTargetHaptics extends ConsumerStatefulWidget {
  final Widget child;

  /// Off → never buzzes, e.g. when the rest timer is switched off.
  final bool enabled;

  const RestTargetHaptics({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  ConsumerState<RestTargetHaptics> createState() => _RestTargetHapticsState();
}

class _RestTargetHapticsState extends ConsumerState<RestTargetHaptics> {
  Timer? _secondTap;

  @override
  void dispose() {
    _secondTap?.cancel();
    super.dispose();
  }

  void _onRestChanged(RestTimerState? previous, RestTimerState next) {
    if (!widget.enabled || previous == null) return;

    // Same rest, same target, and this tick is the one that crossed it.
    // Changing the target or starting a new rest is not a crossing.
    final crossed = next.isRunning &&
        next.isOvertime &&
        !previous.isOvertime &&
        previous.startedAt == next.startedAt &&
        previous.targetSeconds == next.targetSeconds;
    if (!crossed) return;

    HapticFeedback.heavyImpact();
    _secondTap?.cancel();
    _secondTap = Timer(AppMotion.fast, HapticFeedback.heavyImpact);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RestTimerState>(restTimerProvider, _onRestChanged);
    return widget.child;
  }
}

/// The pill itself, usable on its own if you need it somewhere else.
class RestTimerPill extends ConsumerWidget {
  const RestTimerPill({super.key});

  static const double _dialSize = 34;

  /// [GlassSurface] draws a 1px border on each side.
  static const double _glassBorder = 1;

  /// Total height of the pill: dial + padding + glass border — 44, a full
  /// touch target and no taller.
  static const double height =
      _dialSize + AppSpacing.xs * 2 + _glassBorder * 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final rest = ref.watch(restTimerProvider);
    final notifier = ref.read(restTimerProvider.notifier);

    return GlassSurface(
      radius: AppRadius.pill,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            haptic: HapticStrength.medium,
            scale: 0.92,
            onTap: notifier.toggle,
            onLongPress: () => _openSettings(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RestDial(state: rest, theme: t, size: _dialSize),
                const SizedBox(width: AppSpacing.sm),
                _RestLabel(state: rest, theme: t),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              ],
            ),
          ),
          // One trailing action at a time. Mid-rest the one you want is
          // restart — you moved straight into another set and the clock should
          // begin again; the target is changed between rests.
          rest.isRunning
              ? _RoundAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Restart rest',
                  onTap: notifier.start,
                  theme: t,
                )
              : _RoundAction(
                  icon: Icons.tune_rounded,
                  tooltip: 'Rest settings',
                  onTap: () => _openSettings(context, ref),
                  theme: t,
                ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    AppSheet.show<void>(
      context: context,
      ref: ref,
      title: 'Rest timer',
      subtitle: 'Counts up from your last completed set',
      builder: (context) => const _RestSettings(),
    );
  }
}

/// The ring + play/stop glyph.
class _RestDial extends StatelessWidget {
  final RestTimerState state;
  final AppColors theme;
  final double size;

  const _RestDial({
    required this.state,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final tone = state.isOvertime ? theme.success : theme.primary;
    final innerSize = size - AppSpacing.sm;

    final dial = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (state.isRunning)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: state.progress),
              duration: AppMotion.normal,
              curve: AppMotion.standard,
              builder: (context, value, _) => CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: value,
                  track: theme.outline,
                  color: tone,
                  // With no target there is nothing to fill toward, so the
                  // ring becomes a plain resting outline.
                  indeterminate: state.targetSeconds <= 0,
                ),
              ),
            ),
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.isRunning
                  ? tone.withValues(alpha: theme.isDark ? 0.20 : 0.13)
                  : theme.primaryWash,
            ),
            child: Icon(
              state.isRunning ? Icons.stop_rounded : Icons.timer_outlined,
              size: 15,
              color: state.isRunning ? tone : theme.primary,
            ),
          ),
        ],
      ),
    );

    if (!state.isOvertime) return dial;

    // Past the target: a slow breath so it catches the eye without nagging.
    return _Breathe(child: dial);
  }
}

/// "Rest" while idle, the elapsed time while running. The ring already shows
/// how far along the target the rest is, and the colour flips once it is
/// reached, so there is no second line spelling it out.
class _RestLabel extends StatelessWidget {
  final RestTimerState state;
  final AppColors theme;

  const _RestLabel({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (!state.isRunning) {
      return Text(
        'Rest',
        style: AppType.heading(theme).copyWith(fontSize: 14.5),
      );
    }

    return Text(
      state.label,
      style: AppType.mono(theme, size: 16, weight: FontWeight.w700).copyWith(
        color: state.isOvertime ? theme.success : theme.text,
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final AppColors theme;

  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.theme,
  });

  static const double _size = 30;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.surface,
          ),
          child: Icon(icon, size: 16, color: theme.textSecondary),
        ),
      ),
    );
  }
}

/// A gentle repeating scale, used only for the overtime state.
class _Breathe extends StatefulWidget {
  final Widget child;

  const _Breathe({required this.child});

  @override
  State<_Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<_Breathe>
    with SingleTickerProviderStateMixin {
  // One slow breath in, one out.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.lazy * 2,
  )..repeat(reverse: true);

  late final Animation<double> _scale =
      _controller.drive(CurveTween(curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.07 * _scale.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color color;
  final bool indeterminate;

  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.indeterminate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (indeterminate || progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.indeterminate != indeterminate;
}

/// The settings sheet: target presets and the auto-start toggle.
class _RestSettings extends ConsumerWidget {
  const _RestSettings();

  static String _presetLabel(int seconds) {
    if (seconds == 0) return 'No target';
    if (seconds % 60 == 0) return '${seconds ~/ 60} min';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final rest = ref.watch(restTimerProvider);
    final notifier = ref.read(restTimerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Target rest', style: AppType.overline(t)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final preset in RestTimerNotifier.targetPresets)
              AppChip(
                label: _presetLabel(preset),
                selected: rest.targetSeconds == preset,
                onTap: () => notifier.setTarget(preset),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppCard(
          inset: true,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Start automatically', style: AppType.heading(t)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'When you log a set',
                      style: AppType.secondary(t).copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Switch(
                value: rest.autoStart,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  notifier.setAutoStart(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
