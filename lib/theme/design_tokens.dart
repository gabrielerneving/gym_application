import 'package:flutter/material.dart';

import 'app_theme.dart';

/// ---------------------------------------------------------------------------
/// Design tokens — spacing, radii, motion and type.
///
/// These are deliberately *values*, not widgets. Everything visual in the app
/// should be expressible as a combination of a colour from [AppColors] and a
/// token from this file. If you find yourself typing a raw number for padding,
/// a corner radius or an animation duration, reach for a token instead.
/// ---------------------------------------------------------------------------

/// 4-point spacing scale.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Horizontal gutter used by every screen so content lines up across pages.
  static const double screenH = 20;

  /// Bottom padding that clears the floating nav bar. `AppScaffold` adds the
  /// device's bottom safe-area inset on top of this, so screens that use the
  /// scaffold get correct clearance without doing the maths themselves.
  static const double navBarClearance = 104;
}

/// Corner radii. The app leans generous and consistent — squircle-ish cards,
/// fully-rounded pills.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;

  /// Default card radius.
  static const double card = 24;
  static const double xl = 28;
  static const double xxl = 32;

  /// Sheets and modals.
  static const double sheet = 32;

  /// Anything pill shaped.
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: Radius.circular(sheet),
    topRight: Radius.circular(sheet),
  );
}

/// Durations and curves. One motion language across the whole app:
/// things ease *out* quickly and settle softly, never linear, never bouncy
/// unless it is a celebratory moment.
class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 480);
  static const Duration lazy = Duration(milliseconds: 700);

  /// The house curve: fast start, long soft tail. Used for almost everything.
  static const Curve standard = Cubic(0.22, 0.9, 0.16, 1.0);

  /// For elements entering the screen.
  static const Curve enter = Cubic(0.16, 1.0, 0.3, 1.0);

  /// For elements leaving the screen.
  static const Curve exit = Cubic(0.4, 0.0, 1.0, 1.0);

  /// Overshoots slightly — the nav bar indicator and celebratory pops.
  static const Curve spring = Cubic(0.34, 1.42, 0.44, 1.0);

  /// Delay between siblings in a staggered list entrance.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Maximum number of items that get a staggered delay before the list just
  /// fades in as one. Keeps long lists from feeling sluggish.
  static const int maxStaggered = 8;
}

/// Type scale. Sizes are tuned for a fitness app read at arm's length while
/// standing at a rack: big numbers, calm labels, tight tracking on headlines.
class AppType {
  AppType._();

  /// Screen title — the big one at the top of a page.
  static TextStyle display(AppColors t) => TextStyle(
        color: t.text,
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      );

  /// Section title inside a page.
  static TextStyle title(AppColors t) => TextStyle(
        color: t.text,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  /// Card heading.
  static TextStyle heading(AppColors t) => TextStyle(
        color: t.text,
        fontSize: 17,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle body(AppColors t) => TextStyle(
        color: t.text,
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w500,
      );

  static TextStyle secondary(AppColors t) => TextStyle(
        color: t.textSecondary,
        fontSize: 13.5,
        height: 1.35,
        fontWeight: FontWeight.w500,
      );

  static TextStyle caption(AppColors t) => TextStyle(
        color: t.textTertiary,
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
      );

  /// ALL-CAPS eyebrow above a section.
  static TextStyle overline(AppColors t) => TextStyle(
        color: t.textSecondary,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      );

  /// The hero number on a stat tile.
  static TextStyle metric(AppColors t, {double size = 30}) => TextStyle(
        color: t.text,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Numbers in tables/rows that must not jitter as they change.
  static TextStyle mono(AppColors t, {double size = 15, FontWeight? weight}) =>
      TextStyle(
        color: t.text,
        fontSize: size,
        height: 1.2,
        fontWeight: weight ?? FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle button(AppColors t) => const TextStyle(
        fontSize: 15.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      );
}

/// Small, boring helpers that come up constantly when formatting gym data.
class AppFormat {
  AppFormat._();

  /// 82.5 → "82.5", 80.0 → "80". Keeps weight labels tidy.
  static String weight(num value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  /// 12500 → "12.5k", 1250000 → "1.3M". For tonnage.
  static String compact(num value) {
    final v = value.abs();
    if (v >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (v >= 10000) return '${(value / 1000).toStringAsFixed(0)}k';
    if (v >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return weight(value);
  }

  /// 95 → "1h 35m", 42 → "42m".
  static String duration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Signed delta with the unit attached: "+2.5 kg", "−1 rep", "0".
  static String delta(num value, {String unit = ''}) {
    final suffix = unit.isEmpty ? '' : ' $unit';
    if (value > 0) return '+${weight(value)}$suffix';
    if (value < 0) return '−${weight(value.abs())}$suffix';
    return '0$suffix';
  }

  /// "2 days ago", "Today", "3 weeks ago".
  static String relativeDate(DateTime date, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final today = DateTime(ref.year, ref.month, ref.day);
    final days = today.difference(d).inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 14) return 'Last week';
    if (days < 60) return '${(days / 7).floor()} weeks ago';
    return '${(days / 30).floor()} months ago';
  }

  static const List<String> monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "14 Mar".
  static String dayMonth(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}';

  static const List<String> weekdaysShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
}
