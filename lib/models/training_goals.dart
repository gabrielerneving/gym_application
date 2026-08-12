import 'package:flutter/foundation.dart';

/// ---------------------------------------------------------------------------
/// The numbers every "target" in the app is scored against.
///
/// The statistics screens used to hard-code the 10–20 sets/week hypertrophy
/// band from the training literature. That band is a reasonable *default*, but
/// it is only right for someone whose goal is growth — a lifter maintaining
/// through a busy period, or one specialising on a single area, is measured
/// against the wrong ruler and told they are failing at something they never
/// set out to do.
///
/// So the band lives here instead, owned by the user. [AnalyticsService] takes
/// a [TrainingGoals] and scores against it; the defaults reproduce exactly what
/// the app did before, so nothing changes for anyone who never opens Settings.
/// ---------------------------------------------------------------------------
@immutable
class TrainingGoals {
  /// The weekly working-set band each muscle group is scored against.
  /// Below [weeklySetsMin] is "below target", above [weeklySetsMax] is "above".
  final int weeklySetsMin;
  final int weeklySetsMax;

  /// Sessions needed in a week before that week counts toward the streak.
  final int sessionsPerWeek;

  const TrainingGoals({
    this.weeklySetsMin = defaultWeeklySetsMin,
    this.weeklySetsMax = defaultWeeklySetsMax,
    this.sessionsPerWeek = defaultSessionsPerWeek,
  });

  /// The broadly accepted hypertrophy band — what the app assumed before the
  /// numbers became editable, and still the starting point for a new user.
  static const int defaultWeeklySetsMin = 10;
  static const int defaultWeeklySetsMax = 20;

  /// One session a week. Deliberately the loosest possible streak rule: it is
  /// what the streak has always meant, and raising it is an opt-in.
  static const int defaultSessionsPerWeek = 1;

  /// Bounds for the pickers. Nothing below 1 is a goal, and past ~40 sets a
  /// week the band stops being a band.
  static const int minSets = 1;
  static const int maxSets = 40;

  /// One a day is the ceiling the picker offers. Two-a-days exist, but a
  /// streak rule you can only satisfy by never missing a session stops being
  /// a motivator and starts being a way to lose the streak.
  static const int maxSessionsPerWeek = 7;

  /// The smallest band the picker allows. A single number is a threshold, not
  /// a band, and the shaded strip behind the bars would vanish.
  static const int minBandWidth = 1;

  bool get isDefault =>
      weeklySetsMin == defaultWeeklySetsMin &&
      weeklySetsMax == defaultWeeklySetsMax &&
      sessionsPerWeek == defaultSessionsPerWeek;

  /// "10–20", for inline use in labels and subtitles.
  String get bandLabel => '$weeklySetsMin–$weeklySetsMax';

  /// "10–20 sets a week" — the phrase the stats screens repeat.
  String get bandSentence => '$bandLabel sets a week';

  double get setsMin => weeklySetsMin.toDouble();
  double get setsMax => weeklySetsMax.toDouble();

  String get sessionsLabel =>
      '$sessionsPerWeek ${sessionsPerWeek == 1 ? 'session' : 'sessions'}';

  /// Clamps both ends into range and keeps min at least [minBandWidth] below
  /// max, whichever end the caller moved.
  static TrainingGoals band(int min, int max, {int sessionsPerWeek = 1}) {
    final low = min.clamp(minSets, maxSets - minBandWidth);
    final high = max.clamp(low + minBandWidth, maxSets);
    return TrainingGoals(
      weeklySetsMin: low,
      weeklySetsMax: high,
      sessionsPerWeek: sessionsPerWeek.clamp(1, maxSessionsPerWeek),
    );
  }

  TrainingGoals copyWith({
    int? weeklySetsMin,
    int? weeklySetsMax,
    int? sessionsPerWeek,
  }) {
    return TrainingGoals.band(
      weeklySetsMin ?? this.weeklySetsMin,
      weeklySetsMax ?? this.weeklySetsMax,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingGoals &&
          other.weeklySetsMin == weeklySetsMin &&
          other.weeklySetsMax == weeklySetsMax &&
          other.sessionsPerWeek == sessionsPerWeek;

  @override
  int get hashCode =>
      Object.hash(weeklySetsMin, weeklySetsMax, sessionsPerWeek);

  @override
  String toString() =>
      'TrainingGoals($bandLabel sets/week, $sessionsPerWeek sessions/week)';
}

/// A named starting point for the weekly set band, offered in the picker so
/// the common cases are one tap rather than two drags.
@immutable
class SetBandPreset {
  final String label;
  final String blurb;
  final int min;
  final int max;

  const SetBandPreset({
    required this.label,
    required this.blurb,
    required this.min,
    required this.max,
  });

  bool matches(TrainingGoals goals) =>
      goals.weeklySetsMin == min && goals.weeklySetsMax == max;

  static const List<SetBandPreset> all = [
    SetBandPreset(
      label: 'Minimal',
      blurb: 'Keep the muscle you have on very little time',
      min: 3,
      max: 6,
    ),
    SetBandPreset(
      label: 'Maintain',
      blurb: 'Enough to hold your size without chasing more',
      min: 6,
      max: 10,
    ),
    SetBandPreset(
      label: 'Build',
      blurb: 'The classic hypertrophy band',
      min: TrainingGoals.defaultWeeklySetsMin,
      max: TrainingGoals.defaultWeeklySetsMax,
    ),
    SetBandPreset(
      label: 'Specialise',
      blurb: 'High volume on a lagging area',
      min: 16,
      max: 26,
    ),
  ];
}
