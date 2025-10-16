import 'dart:math' as Math;

/// Olika formler för att beräkna 1RM (One Rep Max)
class OneRMCalculator {
  
  /// Epley Formula (mest populär)
  /// 1RM = weight × (1 + reps/30)
  static double epley(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps == 0 || weight == 0) return 0;
    return weight * (1 + (reps / 30.0));
  }

  /// Brzycki Formula (ofta används i forskning)
  /// 1RM = weight × (36 / (37 - reps))
  static double brzycki(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps == 0 || weight == 0) return 0;
    if (reps >= 37) return weight; // Formula breaks down at high reps
    return weight * (36.0 / (37.0 - reps));
  }

  /// Lander Formula
  /// 1RM = (100 × weight) / (101.3 - 2.67123 × reps)
  static double lander(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps == 0 || weight == 0) return 0;
    return (100.0 * weight) / (101.3 - 2.67123 * reps);
  }

  /// Lombardi Formula
  /// 1RM = weight × reps^0.10
  static double lombardi(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps == 0 || weight == 0) return 0;
    return weight * Math.pow(reps, 0.10);
  }

  /// Mayhew et al. Formula
  /// 1RM = (100 × weight) / (52.2 + 41.9 × e^(-0.055 × reps))
  static double mayhew(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps == 0 || weight == 0) return 0;
    return (100.0 * weight) / (52.2 + 41.9 * Math.exp(-0.055 * reps));
  }

  /// O'Conner Formula
  /// 1RM = weight × (1 + reps/40)
  static double oconner(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps == 0 || weight == 0) return 0;
    return weight * (1.0 + (reps / 40.0));
  }

  /// Wathan Formula
  /// 1RM = (100 × weight) / (48.8 + 53.8 × e^(-0.075 × reps))
  static double wathan(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps == 0 || weight == 0) return 0;
    return (100.0 * weight) / (48.8 + 53.8 * Math.exp(-0.075 * reps));
  }

  /// Beräkna genomsnitt av alla formler (mest exakt)
  static double average(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps == 0 || weight == 0) return 0;
    
    final formulas = [
      epley(weight, reps),
      brzycki(weight, reps),
      lander(weight, reps),
      lombardi(weight, reps),
      mayhew(weight, reps),
      oconner(weight, reps),
      wathan(weight, reps),
    ];
    
    return formulas.reduce((a, b) => a + b) / formulas.length;
  }

  /// Beräkna 1RM med vald formel
  static double calculate(double weight, int reps, OneRMFormula formula) {
    switch (formula) {
      case OneRMFormula.epley:
        return epley(weight, reps);
      case OneRMFormula.brzycki:
        return brzycki(weight, reps);
      case OneRMFormula.lander:
        return lander(weight, reps);
      case OneRMFormula.lombardi:
        return lombardi(weight, reps);
      case OneRMFormula.mayhew:
        return mayhew(weight, reps);
      case OneRMFormula.oconner:
        return oconner(weight, reps);
      case OneRMFormula.wathan:
        return wathan(weight, reps);
      case OneRMFormula.average:
        return average(weight, reps);
    }
  }

  /// Beräkna vikt för en given procent av 1RM
  /// Ex: För 80% av 1RM (hypertrophy range)
  static double percentageWeight(double oneRM, double percentage) {
    return oneRM * (percentage / 100.0);
  }

  /// Beräkna ungefärligt antal reps vid en given vikt baserat på 1RM
  /// Använder Epley formula inverterad
  static int estimatedReps(double weight, double oneRM) {
    if (weight >= oneRM) return 1;
    if (weight == 0 || oneRM == 0) return 0;
    
    // Inverterad Epley: reps = 30 × ((1RM / weight) - 1)
    final reps = 30.0 * ((oneRM / weight) - 1.0);
    return reps.round().clamp(1, 20);
  }
}

/// Olika 1RM formler
enum OneRMFormula {
  epley,      // Mest populär
  brzycki,    // Forsknings-standard
  lander,
  lombardi,
  mayhew,
  oconner,
  wathan,
  average,    // Genomsnitt av alla (mest exakt)
}

/// Extension för att få human-readable namn
extension OneRMFormulaExtension on OneRMFormula {
  String get displayName {
    switch (this) {
      case OneRMFormula.epley:
        return 'Epley';
      case OneRMFormula.brzycki:
        return 'Brzycki';
      case OneRMFormula.lander:
        return 'Lander';
      case OneRMFormula.lombardi:
        return 'Lombardi';
      case OneRMFormula.mayhew:
        return 'Mayhew et al.';
      case OneRMFormula.oconner:
        return 'O\'Conner';
      case OneRMFormula.wathan:
        return 'Wathan';
      case OneRMFormula.average:
        return 'Average (Most Accurate)';
    }
  }

  String get description {
    switch (this) {
      case OneRMFormula.epley:
        return 'Most popular formula, good for 1-10 reps';
      case OneRMFormula.brzycki:
        return 'Research standard, accurate for 1-10 reps';
      case OneRMFormula.lander:
        return 'Good for intermediate lifters';
      case OneRMFormula.lombardi:
        return 'Conservative estimate';
      case OneRMFormula.mayhew:
        return 'Based on large study, good for all rep ranges';
      case OneRMFormula.oconner:
        return 'Similar to Epley, slightly more conservative';
      case OneRMFormula.wathan:
        return 'Accurate for higher rep ranges';
      case OneRMFormula.average:
        return 'Average of all formulas for best accuracy';
    }
  }
}

/// Helper class för att importera Math
