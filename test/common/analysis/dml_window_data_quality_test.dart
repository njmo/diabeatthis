import 'package:diabeatthis/common/analysis/dml_window_facts.dart';
import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 5, 7, 12);
  final end = start.add(const Duration(minutes: 15));
  Map<String, Object?> facts(GlucosePeriodSummary? glucose) => dmlWindowFacts(
    start: start,
    end: end,
    glucose: glucose,
    basal: null,
    boluses: null,
  );
  Glucose sample(int minute) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: start.add(Duration(minutes: minute)),
    sgv: 120,
    direction: 'Flat',
  );

  test(
    'unavailable history differs from a successful read returning no CGM',
    () {
      final unavailable = facts(null);
      final empty = facts(GlucosePeriodSummary.calculate([], start, end));
      expect(unavailable['has_cgm_observations'], isNull);
      expect(unavailable['cgm_coverage_pct'], isNull);
      expect(empty['has_cgm_observations'], isFalse);
      expect(empty['cgm_samples_in_window'], 0);
      expect(empty['cgm_coverage_pct'], 0);
      expect(empty['cgm_sampling_complete'], isFalse);
    },
  );

  test('partial observations keep gaps rather than implying complete data', () {
    final partial = facts(
      GlucosePeriodSummary.calculate([sample(0)], start, end),
    );
    expect(partial['has_cgm_observations'], isTrue);
    expect(partial['cgm_samples_in_window'], 1);
    expect(partial['cgm_observed_min'], 5);
    expect(partial['cgm_coverage_pct'], closeTo(100 / 3, 0.001));
    expect(partial['cgm_sampling_complete'], isFalse);
  });

  test(
    'continuous samples cover the window without counting prior baseline',
    () {
      final full = facts(
        GlucosePeriodSummary.calculate(
          [sample(-5), sample(0), sample(5), sample(10)],
          start,
          end,
        ),
      );
      expect(full['cgm_samples_in_window'], 3);
      expect(full['cgm_coverage_pct'], 100);
      expect(full['cgm_sampling_complete'], isTrue);
    },
  );
}
