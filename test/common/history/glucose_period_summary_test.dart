import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 10);
  Glucose sample(int minute, int value, {GlucoseType type = GlucoseType.cgm}) =>
      Glucose(
        externalId: '$minute',
        source: GlucoseSource.aaps,
        date: start.add(Duration(minutes: minute)),
        sgv: value,
        direction: '',
        type: type,
      );
  test(
    'weights time, clips samples, deduplicates and excludes spot checks',
    () {
      final summary = GlucosePeriodSummary.calculate(
        [
          sample(5, 200),
          sample(0, 100),
          sample(0, 100),
          sample(2, 400, type: GlucoseType.finger),
          sample(20, 300),
        ],
        start,
        start.add(const Duration(minutes: 7)),
      );
      expect(summary.mean, closeTo(900 / 7, 0.001));
      expect(summary.coveragePercent, 100);
      expect(summary.window.readings.length, 2);
    },
  );
  test('gaps are unknown rather than extended sample coverage', () {
    final summary = GlucosePeriodSummary.calculate(
      [sample(0, 100), sample(15, 200)],
      start,
      start.add(const Duration(minutes: 20)),
    );
    expect(summary.mean, 150);
    expect(summary.coveragePercent, 50);
    expect(summary.window.missing, const Duration(minutes: 10));
  });
  test('empty period has no mean and zero observed coverage', () {
    final summary = GlucosePeriodSummary.calculate(
      [],
      start,
      start.add(const Duration(hours: 1)),
    );
    expect(summary.mean, isNull);
    expect(summary.coveragePercent, 0);
  });
}
