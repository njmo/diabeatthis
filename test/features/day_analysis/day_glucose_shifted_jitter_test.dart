import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 11);
  GlucosePeriodSummary summary(List<int> seconds) =>
      GlucosePeriodSummary.calculate(
        seconds.map(
          (second) => Glucose(
            externalId: '$second',
            source: GlucoseSource.cloud,
            date: start.add(Duration(seconds: second)),
            sgv: 120,
            direction: '',
          ),
        ),
        start,
        start.add(const Duration(hours: 6)),
      );

  test(
    'phase and one-second drift together do not imply a missing reading',
    () {
      final data = summary(List.generate(71, (index) => 299 + index * 301));
      expect(data.window.readings, hasLength(71));
      expect(data.hasContinuousReadings, isTrue);
      expect(data.coveragePercent, lessThan(100));
    },
  );

  test(
    'boundary allowance cannot hide a missing reading inside the stream',
    () {
      final seconds = List.generate(71, (index) => 299 + index * 301);
      seconds.removeAt(35);
      expect(summary(seconds).hasContinuousReadings, isFalse);
    },
  );

  test('a slower stream cannot use the boundary allowance', () {
    expect(
      summary(List.generate(71, (index) => index * 305)).hasContinuousReadings,
      isFalse,
    );
  });
}
