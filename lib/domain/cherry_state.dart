import 'dart:math' as math;

/// Configuration for how dollars map onto cherries.
class CherryConfig {
  final double dollarsPerCherry;
  final int rows;
  final int cols;

  const CherryConfig({
    this.dollarsPerCherry = 0.50,
    this.rows = 5,
    this.cols = 4,
  });

  int get cherriesPerPlate => rows * cols;
  double get dollarsPerPlate => dollarsPerCherry * cherriesPerPlate;

  CherryConfig copyWith({double? dollarsPerCherry, int? rows, int? cols}) =>
      CherryConfig(
        dollarsPerCherry: dollarsPerCherry ?? this.dollarsPerCherry,
        rows: rows ?? this.rows,
        cols: cols ?? this.cols,
      );
}

/// Visual state of one cherry in the grid.
enum CherryStatus {
  /// Whole, uneaten cherry.
  full,

  /// The cherry currently being nibbled — partially eaten.
  eating,

  /// Eaten: only the dashed stem outline remains.
  eaten,
}

/// Derived render state for the whole plate, computed purely from the period
/// cost and the [CherryConfig]. No mutable counters — the snapshot cost is the
/// single source of truth, so it survives restarts and recomputes idempotently.
class CherryState {
  final CherryConfig config;

  /// Total dollars burned in the current period.
  final double periodCost;

  /// Which plate (round) we're on. 0 = first plate. Increments each time a
  /// full plate is eaten and regrows.
  final int round;

  /// Number of fully eaten cherries on the *current* plate (0..cherriesPerPlate).
  final int eatenOnPlate;

  /// Fractional progress (0..1) into the cherry currently being eaten.
  final double currentBite;

  CherryState._({
    required this.config,
    required this.periodCost,
    required this.round,
    required this.eatenOnPlate,
    required this.currentBite,
  });

  factory CherryState.fromCost(double periodCost, CherryConfig config) {
    final cost = math.max(0.0, periodCost);
    final totalCherriesEaten =
        (cost / config.dollarsPerCherry).floor();
    final round = totalCherriesEaten ~/ config.cherriesPerPlate;
    final eatenOnPlate = totalCherriesEaten % config.cherriesPerPlate;

    // Fraction into the cherry currently being nibbled.
    final remainder = cost - totalCherriesEaten * config.dollarsPerCherry;
    final currentBite =
        (remainder / config.dollarsPerCherry).clamp(0.0, 1.0).toDouble();

    return CherryState._(
      config: config,
      periodCost: cost,
      round: round,
      eatenOnPlate: eatenOnPlate,
      currentBite: currentBite,
    );
  }

  /// Status for the cherry at flat index [i] (0..cherriesPerPlate-1).
  /// Cherries are eaten in reading order: top-left first.
  CherryStatus statusAt(int i) {
    if (i < eatenOnPlate) return CherryStatus.eaten;
    if (i == eatenOnPlate && currentBite > 0) return CherryStatus.eating;
    return CherryStatus.full;
  }

  int get remainingOnPlate => config.cherriesPerPlate - eatenOnPlate;
}
