import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// AppColors — the single source of truth for colour in the app.
///
/// Every screen reads its colours from here (via `ref.watch(themeProvider)`).
/// The palette is intentionally small and semantic: pick the token that
/// describes the *role*, never a raw hex value.
///
/// Surface hierarchy (lowest → highest):
///   backgroundDark  → the deepest plate, behind everything
///   background      → the page itself
///   surface         → inset areas *inside* a card (chips, input wells)
///   card            → the default raised surface
///   elevated        → sheets, menus, dialogs, the floating nav bar
/// ---------------------------------------------------------------------------
class AppColors {
  /// Human readable name, shown in the theme picker.
  final String name;

  /// True when the palette is built for a dark background. Used to decide
  /// shadow strength, blur tint and status-bar icon brightness.
  final bool isDark;

  final Color primary;
  final Color primaryLight;
  final Color accent;

  final Color background;
  final Color backgroundDark;
  final Color card;
  final Color surface;
  final Color elevated;

  final Color outline;
  final Color text;
  final Color textSecondary;

  /// Third-level text: table headers, timestamps, units, hints, footnotes.
  /// Opaque and tuned per palette to ≥ 4.5:1 on [card] (≥ 4:1 on [surface]
  /// and [elevated]), so it stays readable at arm's length. Palettes that do
  /// not set it fall back to a blend of [textSecondary] toward [card].
  final Color? _textTertiary;

  /// Placeholder / hint text in input wells (last time's weight in an empty
  /// field, "Note", "Search…"). Opaque and tuned per palette to ≈ 3.6:1 on
  /// [surface] (≥ 3.4:1 on [elevated] and on a [successBand] row), one quiet
  /// step under [textTertiary], so a hint never reads as an entered value.
  final Color? _textHint;

  /// Colour for text/icons drawn *on top of* [primary].
  final Color onPrimary;

  final Color success;
  final Color warning;
  final Color error;

  const AppColors({
    required this.name,
    required this.isDark,
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.backgroundDark,
    required this.card,
    required this.surface,
    required this.elevated,
    required this.outline,
    required this.text,
    required this.textSecondary,
    Color? textTertiary,
    Color? textHint,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.error,
  })  : _textTertiary = textTertiary,
        _textHint = textHint;

  // ---------------------------------------------------------------------------
  // Derived tokens
  // ---------------------------------------------------------------------------

  bool get isLight => !isDark;

  /// Third-level text: table headers, timestamps, units, hints, footnotes.
  /// ≥ 4.5:1 on [card] in every shipped palette.
  Color get textTertiary =>
      _textTertiary ?? Color.lerp(textSecondary, card, 0.3)!;

  /// Placeholder / hint text: ≥ 3:1 on [surface] in every shipped palette.
  Color get textHint => _textHint ?? Color.lerp(textTertiary, surface, 0.2)!;

  /// Hairline that separates two surfaces of the same elevation.
  Color get divider => outline.withValues(alpha: isDark ? 0.55 : 0.7);

  /// Tint used behind blurred (frosted) surfaces such as the nav bar.
  Color get glass => elevated.withValues(alpha: isDark ? 0.72 : 0.78);

  /// Overlay behind modals.
  Color get scrim => backgroundDark.withValues(alpha: isDark ? 0.62 : 0.38);

  /// A very soft wash of the primary colour — used for selected chips,
  /// icon tiles and highlighted rows.
  Color get primaryWash => primary.withValues(alpha: isDark ? 0.16 : 0.10);

  /// Border for elements that sit on [primaryWash].
  Color get primaryWashOutline => primary.withValues(alpha: isDark ? 0.28 : 0.20);

  /// A neutral, translucent fill that reads as one step up from *whatever*
  /// surface it sits on — lighter on dark palettes, darker on light ones.
  /// Used for idle icon tiles, so a list of rows is calm grey instead of a
  /// column of accent squares.
  Color get neutralWash =>
      text.withValues(alpha: isDark ? 0.08 : 0.055);

  /// An opaque neutral that reads as *raised* above [surface]: the thumb of a
  /// segmented control, a selected pill on a track. On dark palettes it is
  /// lighter than every other surface (raised = lighter); on light palettes it
  /// is the white card.
  Color get raised => isDark ? Color.lerp(elevated, text, 0.10)! : card;

  /// Soft fill for a *done* element (a check tile, a done chip) — the
  /// success twin of [primaryWash].
  Color get successWash => success.withValues(alpha: isDark ? 0.16 : 0.12);

  /// Border for elements that sit on [successWash].
  Color get successWashOutline =>
      success.withValues(alpha: isDark ? 0.30 : 0.24);

  /// The faint full-width band behind a finished row — just enough to scan
  /// what is done while the row's numbers stay the loudest thing on it.
  Color get successBand => success.withValues(alpha: isDark ? 0.08 : 0.07);

  /// Soft fill for destructive tiles and chips.
  Color get errorWash => error.withValues(alpha: isDark ? 0.14 : 0.09);

  /// Text/icons drawn on a solid [success] or [error] fill.
  Color get onSuccess => contrastOn(success);
  Color get onError => contrastOn(error);

  /// The signature gradient. Horizontal, primary → primaryLight.
  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [primary, primaryLight],
      );

  /// Diagonal variant — better on large surfaces (hero cards, buttons).
  LinearGradient get primaryGradientDiagonal => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primaryLight],
      );

  /// Three-stop gradient used for the ambient background glow.
  LinearGradient get auroraGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: isDark ? 0.30 : 0.18),
          accent.withValues(alpha: isDark ? 0.16 : 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      );

  /// Gradient for chart fills below a line.
  LinearGradient get chartFillGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primary.withValues(alpha: isDark ? 0.32 : 0.24),
          primary.withValues(alpha: 0.0),
        ],
      );

  List<Color> get gradientColors => [primary, primaryLight];

  // --- Shadows ---------------------------------------------------------------

  /// Barely-there shadow for cards resting on the page.
  List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: _shadowColor.withValues(alpha: isDark ? 0.30 : 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  /// Shadow for interactive raised elements.
  List<BoxShadow> get shadowMedium => [
        BoxShadow(
          color: _shadowColor.withValues(alpha: isDark ? 0.42 : 0.08),
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -4,
        ),
      ];

  /// Small, crisp shadow for a control raised a millimetre off its track —
  /// the segmented-control thumb. Dark palettes get a hairline rim instead
  /// (see [raisedRim]); shadows barely register on near-black.
  List<BoxShadow> get shadowRaised => [
        BoxShadow(
          color: _shadowColor.withValues(alpha: isDark ? 0.40 : 0.10),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Hairline that catches the light on the top of a [raised] element.
  Color get raisedRim => isDark
      ? text.withValues(alpha: 0.07)
      : _shadowColor.withValues(alpha: 0.04);

  /// Shadow for elements that float over content (nav bar, FAB, sheets).
  /// Light palettes get a stronger, crisper pair: white-on-near-white chrome
  /// has nothing but its shadow to separate it from the page.
  List<BoxShadow> get shadowFloating => [
        BoxShadow(
          color: _shadowColor.withValues(alpha: isDark ? 0.55 : 0.14),
          blurRadius: isDark ? 32 : 28,
          offset: const Offset(0, 12),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: _shadowColor.withValues(alpha: isDark ? 0.30 : 0.09),
          blurRadius: isDark ? 8 : 5,
          offset: const Offset(0, 2),
          spreadRadius: isDark ? -2 : -1,
        ),
      ];

  /// Coloured glow for the one hero CTA on a screen. Kept tight — it lifts
  /// the button without spilling a halo over its neighbours.
  List<BoxShadow> get shadowPrimaryGlow => [
        BoxShadow(
          color: primary.withValues(alpha: isDark ? 0.30 : 0.24),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -7,
        ),
      ];

  Color get _shadowColor => isDark ? Colors.black : const Color(0xFF0F172A);

  // --- Data visualisation ----------------------------------------------------

  /// Categorical palette for charts. Ordered for maximum separation and
  /// legible on both light and dark backgrounds. Use [dataColor] to cycle.
  List<Color> get dataPalette => [
        primary,
        const Color(0xFF38BDF8), // sky
        const Color(0xFF34D399), // emerald
        const Color(0xFFFBBF24), // amber
        const Color(0xFFA78BFA), // violet
        const Color(0xFFF472B6), // pink
        const Color(0xFF22D3EE), // cyan
        const Color(0xFFFB923C), // orange
      ];

  Color dataColor(int index) => dataPalette[index % dataPalette.length];

  /// Positive/negative colours for deltas (progression up/down).
  Color get up => success;
  Color get down => error;

  /// Colour for a signed delta, with a neutral case at exactly zero.
  Color deltaColor(num delta) {
    if (delta > 0) return success;
    if (delta < 0) return error;
    return textSecondary;
  }

  // --- Helpers ---------------------------------------------------------------

  /// Mixes [a] and [b]. `t == 0` → a, `t == 1` → b.
  static Color blend(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  /// Picks near-black or white, whichever has the higher contrast on
  /// [background] (the WCAG crossover sits at a luminance of ~0.18).
  static Color contrastOn(Color background) =>
      background.computeLuminance() > 0.18 ? const Color(0xFF0B0B0F) : Colors.white;

  /// A Material swatch built from [primary].
  ///
  /// Only needed by APIs that still take a `MaterialColor` (the legacy
  /// `primarySwatch`); the app itself themes from [ColorScheme] and reads
  /// colours off this class directly.
  MaterialColor toMaterialColor() {
    return MaterialColor(primary.toARGB32(), {
      50: blend(primary, Colors.white, 0.90),
      100: blend(primary, Colors.white, 0.80),
      200: blend(primary, Colors.white, 0.60),
      300: blend(primary, Colors.white, 0.40),
      400: blend(primary, Colors.white, 0.20),
      500: primary,
      600: blend(primary, Colors.black, 0.12),
      700: blend(primary, Colors.black, 0.24),
      800: blend(primary, Colors.black, 0.36),
      900: blend(primary, Colors.black, 0.48),
    });
  }
}

/// ---------------------------------------------------------------------------
/// The shipped palettes.
///
/// Order is load-bearing: the selected theme is persisted as an index, so new
/// palettes must be appended at the end and existing slots must keep roughly
/// the same character.
/// ---------------------------------------------------------------------------
class AppTheme {
  // Colour roles every palette honours (checked with WCAG contrast and
  // CIEDE2000 ΔE — see docs/DESIGN_SYSTEM.md):
  //   * primary ≠ error: ΔE00 ≥ 25 and a different hue family, so a negative
  //     delta never reads as the brand colour;
  //   * primary ≠ success, for the same reason in green/teal palettes;
  //   * textSecondary ≈ 6.8:1 and textTertiary ≈ 4.6:1 on card.

  // 0 — Ember. Deep neutral charcoal with a glowing ember-orange accent.
  // (Orange-red, not crimson: the error rose has to stay its own colour.)
  static const emberTheme = AppColors(
    name: 'Ember',
    isDark: true,
    primary: Color(0xFFF4511E),
    primaryLight: Color(0xFFFF7A35),
    accent: Color(0xFFFF9A5C),
    background: Color(0xFF0B0B0E),
    backgroundDark: Color(0xFF060608),
    card: Color(0xFF16161B),
    surface: Color(0xFF1F1F26),
    elevated: Color(0xFF212129),
    outline: Color(0xFF2E2E38),
    text: Color(0xFFF7F7F8),
    textSecondary: Color(0xFF9E9EAA),
    textTertiary: Color(0xFF7F7F8A),
    textHint: Color(0xFF767680),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87196),
  );

  // 1 — Blossom. Bright, airy light theme with the signature pink gradient.
  // Error is a true red so it never blends into the pink.
  static const blossomTheme = AppColors(
    name: 'Blossom',
    isDark: false,
    primary: Color(0xFFD9338A),
    primaryLight: Color(0xFFE84FB0),
    accent: Color(0xFFF472B6),
    background: Color(0xFFF7F7FB),
    backgroundDark: Color(0xFFEDEDF3),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFF1F1F7),
    elevated: Color(0xFFFFFFFF),
    outline: Color(0xFFE4E4EC),
    text: Color(0xFF14141A),
    textSecondary: Color(0xFF595967),
    textTertiary: Color(0xFF757580),
    textHint: Color(0xFF7D7D88),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF0B8457),
    warning: Color(0xFFC26A07),
    error: Color(0xFFDC2626),
  );

  // 2 — Aqua. Clean light theme with a cool cyan accent. The gradient stays
  // on the blue side of teal so it never meets the success green.
  static const aquaTheme = AppColors(
    name: 'Aqua',
    isDark: false,
    primary: Color(0xFF0A80A0),
    primaryLight: Color(0xFF0AA5C8),
    accent: Color(0xFF22D3EE),
    background: Color(0xFFF4F9FA),
    backgroundDark: Color(0xFFE7F1F3),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFEEF6F7),
    elevated: Color(0xFFFFFFFF),
    outline: Color(0xFFDDE9EB),
    text: Color(0xFF0C1A1F),
    textSecondary: Color(0xFF4A5E67),
    textTertiary: Color(0xFF67787F),
    textHint: Color(0xFF728289),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF0B8457),
    warning: Color(0xFFC26A07),
    error: Color(0xFFE11D48),
  );

  // 3 — Deep Ocean. Navy dark theme, high contrast blue.
  static const oceanTheme = AppColors(
    name: 'Deep Ocean',
    isDark: true,
    primary: Color(0xFF3B82F6),
    primaryLight: Color(0xFF29ABEB),
    accent: Color(0xFF60A5FA),
    background: Color(0xFF080D18),
    backgroundDark: Color(0xFF04070F),
    card: Color(0xFF121A2B),
    surface: Color(0xFF1A2437),
    elevated: Color(0xFF172033),
    outline: Color(0xFF26314A),
    text: Color(0xFFEEF3FB),
    textSecondary: Color(0xFF95A3BB),
    textTertiary: Color(0xFF77849A),
    textHint: Color(0xFF6E7B90),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFFB7185),
  );

  // 4 — Evergreen. Dark theme with a calm emerald accent. Success is lime,
  // not green, so "done" and "positive" stay distinct from the brand colour.
  static const evergreenTheme = AppColors(
    name: 'Evergreen',
    isDark: true,
    primary: Color(0xFF10B981),
    primaryLight: Color(0xFF5EEAD4),
    accent: Color(0xFF2DD4BF),
    background: Color(0xFF07120D),
    backgroundDark: Color(0xFF040B07),
    card: Color(0xFF11201A),
    surface: Color(0xFF182B23),
    elevated: Color(0xFF16261F),
    outline: Color(0xFF23392F),
    text: Color(0xFFECFDF5),
    textSecondary: Color(0xFF8EAB9F),
    textTertiary: Color(0xFF728B81),
    textHint: Color(0xFF6A8278),
    onPrimary: Color(0xFF04140D),
    success: Color(0xFFA3E635),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFFB7185),
  );

  // 5 — Lilac. Soft light theme with a violet accent.
  static const lilacTheme = AppColors(
    name: 'Lilac',
    isDark: false,
    primary: Color(0xFF8152F0),
    primaryLight: Color(0xFFD946EF),
    accent: Color(0xFFA78BFA),
    background: Color(0xFFF9F7FD),
    backgroundDark: Color(0xFFEFEBF8),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFF3EFFC),
    elevated: Color(0xFFFFFFFF),
    outline: Color(0xFFE6DFF6),
    text: Color(0xFF1B1330),
    textSecondary: Color(0xFF5F5677),
    textTertiary: Color(0xFF79728D),
    textHint: Color(0xFF817A95),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF0B8457),
    warning: Color(0xFFC26A07),
    error: Color(0xFFE11D48),
  );

  // 6 — Midnight. Near-black with an electric violet accent.
  static const midnightTheme = AppColors(
    name: 'Midnight',
    isDark: true,
    primary: Color(0xFF8B5CF6),
    primaryLight: Color(0xFFD946EF),
    accent: Color(0xFFC084FC),
    background: Color(0xFF0C0C11),
    backgroundDark: Color(0xFF000000),
    card: Color(0xFF17171F),
    surface: Color(0xFF20202B),
    elevated: Color(0xFF1E1E29),
    outline: Color(0xFF2E2E3D),
    text: Color(0xFFF6F5FA),
    textSecondary: Color(0xFFA09EB2),
    textTertiary: Color(0xFF817F91),
    textHint: Color(0xFF777687),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFFB7185),
  );

  // 7 — Graphite. Neutral monochrome for people who want zero colour noise.
  static const graphiteTheme = AppColors(
    name: 'Graphite',
    isDark: true,
    primary: Color(0xFFE4E4E7),
    primaryLight: Color(0xFFA1A1AA),
    accent: Color(0xFFD4D4D8),
    background: Color(0xFF0A0A0B),
    backgroundDark: Color(0xFF000000),
    card: Color(0xFF151517),
    surface: Color(0xFF1E1E21),
    elevated: Color(0xFF1C1C1F),
    outline: Color(0xFF2C2C31),
    text: Color(0xFFFAFAFA),
    textSecondary: Color(0xFF9E9EA4),
    textTertiary: Color(0xFF7F7F85),
    textHint: Color(0xFF75757A),
    onPrimary: Color(0xFF0A0A0B),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFFB7185),
  );

  /// Legacy aliases so older references keep compiling.
  static const darkRedTheme = emberTheme;
  static const pinkTheme = blossomTheme;
  static const lightCyanTheme = aquaTheme;
  static const oceanBlueTheme = oceanTheme;
  static const forestGreenTheme = evergreenTheme;
  static const lavenderDreamsTheme = lilacTheme;
  static const purpleDreamTheme = midnightTheme;

  static const List<AppColors> allThemes = [
    emberTheme,
    blossomTheme,
    aquaTheme,
    oceanTheme,
    evergreenTheme,
    lilacTheme,
    midnightTheme,
    graphiteTheme,
  ];

  static List<String> get themeNames =>
      allThemes.map((t) => t.name).toList(growable: false);

  static AppColors getThemeByIndex(int index) {
    if (index < 0 || index >= allThemes.length) return emberTheme;
    return allThemes[index];
  }

  static int getThemeIndex(AppColors theme) {
    final i = allThemes.indexOf(theme);
    return i < 0 ? 0 : i;
  }
}
