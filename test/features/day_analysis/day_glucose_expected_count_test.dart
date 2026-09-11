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
        start.add(const Duration(hours: 1)),
      );

  test('six-minute sampling cannot count as complete five-minute history', () {
    final timestamps = List.generate(11, (index) => index * 360);
    expect(summary(timestamps).hasContinuousReadings, isFalse);
    expect(
      summary([...timestamps, ...timestamps]).hasContinuousReadings,
      isFalse,
    );
  });

  test(
    'five-minute sampling allows clock drift and a shifted first sample',
    () {
      expect(
        summary(
          List.generate(12, (index) => index * 301),
        ).hasContinuousReadings,
        isTrue,
      );
      expect(
        summary(
          List.generate(12, (index) => 120 + index * 300),
        ).hasContinuousReadings,
        isTrue,
      );
    },
  );
}
