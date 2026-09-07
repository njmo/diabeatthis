enum ConfidenceLevel { low, medium, high, certain }

extension ConfidenceLevelX on ConfidenceLevel {
  /// Returns the persisted confidence value for this level.
  double toDouble01() => switch (this) {
    ConfidenceLevel.low => 0.25,
    ConfidenceLevel.medium => 0.50,
    ConfidenceLevel.high => 0.75,
    ConfidenceLevel.certain => 0.95,
  };

  /// Maps a persisted confidence value to the corresponding slider level.
  static ConfidenceLevel fromDouble01(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if (clamped < 0.375) return ConfidenceLevel.low;
    if (clamped < 0.625) return ConfidenceLevel.medium;
    if (clamped < 0.85) return ConfidenceLevel.high;
    return ConfidenceLevel.certain;
  }

  int toIndex() => index;
  static ConfidenceLevel fromIndex(int i) =>
      ConfidenceLevel.values[i.clamp(0, ConfidenceLevel.values.length - 1)];
}
