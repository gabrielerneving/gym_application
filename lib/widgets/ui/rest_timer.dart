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
/// without looking. Idle it is a small "Rest" pill; running it grows to show a
/// progress ring and the elapsed time, and pulses once the target is passed.
///
/// Tap to start/stop, long-press or tap the settings dot for the target picker.
/// ---------------------------------------------------------------------------
class RestTimerBar extends ConsumerWidget {
  /// Extra bottom inset, e.g. to clear a floating nav bar.
  final double bottomPadding;

  const RestTimerBar({super.key, this.bottomPadding = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset + bottomPadding + AppSpacing.xl,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      // A Row, not Align/Center: those expand to the tallest allowed height
      // when the parent leaves the vertical axis loose, which would stretch the
      // pill's box over the whole screen. A Row shrink-wraps to its child.
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [RestTimerPill()],
      ),
    );
  }
}

/// The pill itself, usable on its own if you need it somewhere else.
class RestTimerPill extends ConsumerWidget {
  const RestTimerPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);
    final rest = ref.watch(restTimerProvider);
    final notifier = ref.read(restTimerProvider.notifier);

    return GlassSurface(
      radius: AppRadius.pill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
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
                _RestDial(state: rest, theme: t),
                const SizedBox(width: AppSpacing.md),
                _RestLabel(state: rest, theme: t),
                const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
          // Restart is the action you want most often mid-workout: you moved
          // straight into another set and the clock should begin again.
          if (rest.isRunning) ...[
            _RoundAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Restart rest',
              onTap: notifier.start,
              theme: t,
            ),
            const SizedBox(width: 6),
          ],
          _RoundAction(
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

  const _RestDial({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final tone = state.isOvertime ? theme.success : theme.primary;

    final dial = SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (state.isRunning)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: state.progress),
              duration: AppMotion.normal,
              curve: AppMotion.standard,
              builder: (context, value, _) => CustomPaint(
                size: const Size(40, 40),
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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state.isRunning
                  ? tone.withValues(alpha: theme.isDark ? 0.20 : 0.13)
                  : theme.primaryWash,
            ),
            child: Icon(
              state.isRunning ? Icons.stop_rounded : Icons.timer_outlined,
              size: 17,
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

class _RestLabel extends StatelessWidget {
  final RestTimerState state;
  final AppColors theme;

  const _RestLabel({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (!state.isRunning) {
      return Text(
        'Rest',
        style: AppType.heading(theme).copyWith(fontSize: 15),
      );
    }

    final tone = state.isOvertime ? theme.success : theme.text;
    final caption = state.targetSeconds <= 0
        ? 'resting'
        : state.isOvertime
            ? 'ready'
            : '${state.remainingSeconds}s to go';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.label,
          style: AppType.mono(theme, size: 17, weight: FontWeight.w800)
              .copyWith(color: tone),
        ),
        Text(
          caption,
          style: AppType.caption(theme).copyWith(fontSize: 10.5),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.surface,
            border: Border.all(color: theme.outline),
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
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
        const SizedBox(height: AppSpacing.lg),
        Text(
          rest.targetSeconds == 0
              ? 'The timer counts up with no goal — useful when your rest '
                  'varies by exercise.'
              : 'The ring fills toward your target. The clock keeps counting '
                  'past it, so you always see the real rest length.',
          style: AppType.secondary(t).copyWith(fontSize: 13),
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
                    const SizedBox(height: 2),
                    Text(
                      'Begin the rest as soon as a set is filled in',
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
