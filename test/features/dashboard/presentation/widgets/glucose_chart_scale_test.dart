import 'package:diabeatthis/features/dashboard/presentation/widgets/glucose_chart_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rounds ticks while enclosing the complete visible glucose range', () {
    final scale = GlucoseChartScale.fromValues([63, 82, 105, 147]);
    expect([scale.minimum, scale.middle, scale.maximum], [50, 100, 150]);
  });

  test('constant and zero readings retain a nonzero scale', () {
    for (final value in [0, 75, 100, 400]) {
      final scale = GlucoseChartScale.fromValues([value, value, value]);
      expect(scale.minimum, lessThanOrEqualTo(value));
      expect(scale.maximum, greaterThanOrEqualTo(value));
      expect(scale.maximum, greaterThan(scale.minimum));
    }
  });

  test('small and wide ranges keep three evenly spaced enclosing ticks', () {
    for (final values in [
      [69, 71],
      [94, 146],
      [40, 401],
      [1, 999],
    ]) {
      final scale = GlucoseChartScale.fromValues(values);
      expect(scale.minimum, lessThanOrEqualTo(values.first));
      expect(scale.maximum, greaterThanOrEqualTo(values.last));
      expect(scale.middle - scale.minimum, scale.maximum - scale.middle);
    }
  });
}
