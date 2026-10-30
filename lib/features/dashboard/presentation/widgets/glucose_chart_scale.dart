import 'dart:math' as math;

/// Three evenly spaced ticks enclosing the visible glucose readings.
class GlucoseChartScale {
  const GlucoseChartScale(this.minimum, this.maximum);

  factory GlucoseChartScale.fromValues(Iterable<int> values) {
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    for (var magnitude = 10; ; magnitude *= 10) {
      for (final multiplier in [1.0, 2.0, 2.5, 5.0]) {
        final step = (magnitude * multiplier).round();
        var lower = (minimum / step).floor() * step;
        if (minimum == maximum) lower = math.max(0, lower - step);
        final upper = lower + 2 * step;
        if (upper >= maximum) return GlucoseChartScale(lower, upper);
      }
    }
  }

  final int minimum;
  final int maximum;
  int get middle => (minimum + maximum) ~/ 2;
}
