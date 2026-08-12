// `CupertinoPageTransitionsBuilder` lives in the Cupertino library, not
// Material — the iOS entry in `pageTransitionsTheme` below needs it.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'design_tokens.dart';

/// Builds the Material [ThemeData] from an [AppColors] palette.
///
/// Screens read colours straight from [AppColors], but Material's own widgets
/// (dialogs, snack bars, text selection, the scroll glow) need a matching
/// [ThemeData] or they punch holes in the design. This keeps the two in sync.
class AppThemeData {
  AppThemeData._();

  static ThemeData build(AppColors t) {
    final brightness = t.isDark ? Brightness.dark : Brightness.light;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.primaryWash,
      onPrimaryContainer: t.text,
      secondary: t.accent,
      onSecondary: AppColors.contrastOn(t.accent),
      secondaryContainer: t.surface,
      onSecondaryContainer: t.text,
      tertiary: t.primaryLight,
      onTertiary: AppColors.contrastOn(t.primaryLight),
      error: t.error,
      onError: AppColors.contrastOn(t.error),
      errorContainer: t.error.withValues(alpha: 0.16),
      onErrorContainer: t.text,
      surface: t.card,
      onSurface: t.text,
      surfaceContainerHighest: t.surface,
      onSurfaceVariant: t.textSecondary,
      outline: t.outline,
      outlineVariant: t.outline.withValues(alpha: 0.6),
      shadow: Colors.black,
      scrim: t.scrim,
      inverseSurface: t.text,
      onInverseSurface: t.background,
      inversePrimary: t.primaryLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      cardColor: t.card,
      dividerColor: t.divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, t),
      primaryTextTheme: _textTheme(base.primaryTextTheme, t),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: t.text, size: 22),
        actionsIconTheme: IconThemeData(color: t.text, size: 22),
        titleTextStyle: AppType.title(t),
        systemOverlayStyle: systemOverlayStyle(t),
      ),

      iconTheme: IconThemeData(color: t.text, size: 22),

      dividerTheme: DividerThemeData(
        color: t.divider,
        thickness: 1,
        space: 1,
      ),

      // NOTE: `cardTheme` and `dialogTheme` are intentionally left at their
      // defaults. Their theme classes were renamed across recent Flutter
      // releases (CardTheme→CardThemeData, DialogTheme→DialogThemeData), so
      // configuring them here would pin the project to one SDK window. Cards
      // and dialogs are styled by the app's own widgets instead — see
      // `widgets/ui/app_card.dart` and `AppDialog` in `widgets/ui/app_sheet.dart`.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.elevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.elevated,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.elevated,
        contentTextStyle: AppType.body(t),
        actionTextColor: t.primary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: t.outline),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        hintStyle: AppType.secondary(t).copyWith(color: t.textTertiary),
        labelStyle: AppType.secondary(t),
        floatingLabelStyle: TextStyle(color: t.primary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.error, width: 1.6),
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.primary,
        selectionColor: t.primary.withValues(alpha: 0.28),
        selectionHandleColor: t.primary,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          textStyle: AppType.button(t),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          elevation: 0,
          textStyle: AppType.button(t),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text,
          side: BorderSide(color: t.outline),
          textStyle: AppType.button(t),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.onPrimary;
          return t.isDark ? t.textSecondary : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.primary;
          return t.surface;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return t.outline;
        }),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: t.primary,
        inactiveTrackColor: t.surface,
        thumbColor: t.primary,
        overlayColor: t.primary.withValues(alpha: 0.16),
        trackHeight: 4,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.surface,
        circularTrackColor: Colors.transparent,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.primaryWash,
        side: BorderSide(color: t.outline),
        labelStyle: AppType.secondary(t),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.elevated,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: t.outline),
        ),
        textStyle: AppType.caption(t).copyWith(color: t.text),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.text,
        titleTextStyle: AppType.body(t),
        subtitleTextStyle: AppType.secondary(t),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: t.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: t.outline),
        ),
        textStyle: AppType.body(t),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, AppColors t) {
    return base
        .apply(bodyColor: t.text, displayColor: t.text)
        .copyWith(
          displayLarge: AppType.display(t).copyWith(fontSize: 42),
          displayMedium: AppType.display(t).copyWith(fontSize: 38),
          displaySmall: AppType.display(t),
          headlineLarge: AppType.display(t).copyWith(fontSize: 30),
          headlineMedium: AppType.title(t).copyWith(fontSize: 26),
          headlineSmall: AppType.title(t),
          titleLarge: AppType.title(t).copyWith(fontSize: 20),
          titleMedium: AppType.heading(t),
          titleSmall: AppType.heading(t).copyWith(fontSize: 15),
          bodyLarge: AppType.body(t).copyWith(fontSize: 16),
          bodyMedium: AppType.body(t),
          bodySmall: AppType.secondary(t),
          labelLarge: AppType.button(t).copyWith(color: t.text),
          labelMedium: AppType.caption(t),
          labelSmall: AppType.overline(t),
        );
  }

  /// Status-bar / nav-bar styling that matches the palette. Applied at the
  /// root of every full-screen page via `AnnotatedRegion`.
  static SystemUiOverlayStyle systemOverlayStyle(AppColors t) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: t.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          t.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }
}

/// A calm fade-through page transition — content cross-fades while sliding a
/// few pixels up. Replaces Android's default vertical slide, which feels heavy
/// next to the rest of the motion in the app.
class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Note: everything here goes through `drive`/`chain` rather than
    // `CurvedAnimation`. A CurvedAnimation registers a status listener on its
    // parent when constructed, and this method runs on every rebuild of the
    // route's scope — driven animatables are stateless and cost nothing.

    // Incoming page: fades up from slightly below.
    final fadeIn = animation.drive(
      CurveTween(curve: const Interval(0.10, 1.0, curve: Curves.easeOut)),
    );
    final slideIn = animation.drive(
      Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
          .chain(CurveTween(curve: AppMotion.enter)),
    );

    // Outgoing page: recedes a touch and dims, so the new page reads as on top.
    final scaleOut = secondaryAnimation.drive(
      Tween<double>(begin: 1.0, end: 0.97)
          .chain(CurveTween(curve: AppMotion.standard)),
    );
    final fadeOut = secondaryAnimation.drive(
      Tween<double>(begin: 1.0, end: 0.0).chain(
        CurveTween(curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
      ),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: ScaleTransition(
        scale: scaleOut,
        child: FadeTransition(
          opacity: fadeIn,
          child: SlideTransition(position: slideIn, child: child),
        ),
      ),
    );
  }
}
