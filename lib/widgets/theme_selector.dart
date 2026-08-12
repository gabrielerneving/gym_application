import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'ui/ui.dart';

/// ---------------------------------------------------------------------------
/// The palette picker.
///
/// Every shipped palette is drawn as a miniature of the screen it produces —
/// its page background, a card, the primary gradient and two lines of text —
/// so the choice is made by looking rather than by reading a colour name.
///
/// Driven entirely by [AppTheme.allThemes] / [AppTheme.themeNames]; adding a
/// palette to the theme file makes it show up here with no changes.
/// ---------------------------------------------------------------------------
class ThemeSelector extends ConsumerWidget {
  /// Tiles per row. Two reads best on a phone; the tiles simply get narrower
  /// if a caller asks for more.
  final int columns;

  const ThemeSelector({super.key, this.columns = 2});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);
    final themes = AppTheme.allThemes;
    final names = AppTheme.themeNames;
    final selectedIndex = AppTheme.getThemeIndex(current);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final count = columns < 1 ? 1 : columns;
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 2 * AppSpacing.screenH;
        final tileWidth = (available - gap * (count - 1)) / count;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < themes.length; i++)
              SizedBox(
                width: tileWidth,
                child: FadeSlideIn(
                  index: i,
                  offsetY: 12,
                  child: _ThemePreviewTile(
                    palette: themes[i],
                    label: names[i],
                    selected: selectedIndex == i,
                    onTap: () =>
                        ref.read(themeProvider.notifier).setTheme(themes[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One palette, rendered as a preview card: the miniature on top, the palette
/// name and its light/dark nature underneath. Selection animates the scale and
/// swaps the hairline border for the palette's own accent.
class _ThemePreviewTile extends ConsumerWidget {
  final AppColors palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemePreviewTile({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Pressable(
      onTap: onTap,
      haptic: HapticStrength.selection,
      scale: 0.96,
      child: AnimatedScale(
        duration: AppMotion.normal,
        curve: AppMotion.spring,
        scale: selected ? 1.0 : 0.975,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? palette.primary : t.outline,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.primary
                          .withValues(alpha: t.isDark ? 0.30 : 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ]
                : t.shadowSoft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PaletteMiniature(palette: palette, selected: selected),
              const SizedBox(height: AppSpacing.sm + 2),
              Row(
                children: [
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: AppMotion.fast,
                      style: AppType.heading(t).copyWith(
                        fontSize: 14,
                        color: selected ? t.text : t.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    palette.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    size: 13,
                    color: t.textTertiary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    palette.isDark ? 'Dark' : 'Light',
                    style: AppType.caption(t).copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tiny mock-up of a page painted in [palette]: ambient wash, the primary
/// gradient as the hero element, and a card carrying two lines of text.
class _PaletteMiniature extends StatelessWidget {
  final AppColors palette;
  final bool selected;

  const _PaletteMiniature({required this.palette, required this.selected});

  static const double _height = 88;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: _height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: palette.outline),
        ),
        child: Stack(
          children: [
            // The ambient glow every page in this palette gets.
            Positioned(
              top: -34,
              right: -26,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.primary
                          .withValues(alpha: palette.isDark ? 0.38 : 0.24),
                      palette.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page title.
                  _Line(color: palette.text.withValues(alpha: 0.92), width: 34, height: 6),
                  const SizedBox(height: AppSpacing.sm),

                  // The hero gradient.
                  Container(
                    height: 18,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: palette.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm - 2),

                  // A card sitting on the page.
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: palette.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Line(
                            color: palette.text.withValues(alpha: 0.85),
                            width: 44,
                            height: 5,
                          ),
                          const SizedBox(height: 4),
                          _Line(
                            color: palette.textSecondary.withValues(alpha: 0.75),
                            width: 26,
                            height: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selected mark, drawn in the palette's own accent.
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedOpacity(
                duration: AppMotion.fast,
                opacity: selected ? 1 : 0,
                child: AnimatedScale(
                  duration: AppMotion.normal,
                  curve: AppMotion.spring,
                  scale: selected ? 1 : 0.6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: palette.primaryGradientDiagonal,
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: palette.onPrimary,
                    ),
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

/// A stand-in for a line of text inside the miniature.
class _Line extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const _Line({
    required this.color,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
