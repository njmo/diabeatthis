import 'package:diabeatthis/common/history/glucose_first_peak.dart';
import 'package:diabeatthis/common/history/time_series_coverage.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 2, 12);
  List<Glucose> readings(List<int> values, {List<int>? minutes}) => [
    for (var i = 0; i < values.length; i++)
      Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: start.add(Duration(minutes: minutes?[i] ?? i * 5)),
        sgv: values[i],
        direction: 'Flat',
      ),
  ];
  test('requires strictly more than ten percent of five-minute samples', () {
    expect(
      const TimeSeriesCoverage(
        available: 18,
        expected: 20,
      ).hasSignificantMissing,
      isFalse,
    );
    expect(
      const TimeSeriesCoverage(
        available: 17,
        expected: 20,
      ).hasSignificantMissing,
      isTrue,
    );
    expect(const TimeSeriesCoverage(available: 21, expected: 20).missing, 0);
    final shifted = TimeSeriesCoverage.fromTimestamps(
      timestamps: [
        for (var i = 0; i < 20; i++)
          start.add(Duration(minutes: i * 5, seconds: 50)),
      ],
      start: start,
      end: start.add(const Duration(minutes: 100)),
    );
    expect(shifted.missing, 0);
  });
  test('first confirmed peak differs from later highest peak', () {
    final result = GlucoseFirstPeak.fromReadings(
      readings([100, 120, 200, 190, 170, 230, 240, 220, 180]),
    );
    expect(result.peak?.sgv, 200);
    expect(result.firstInRangeAfter?.sgv, 170);
  });
  test('does not invent a peak on a rise or across missing samples', () {
    expect(
      GlucoseFirstPeak.fromReadings(readings([100, 120, 140, 160])).peak,
      isNull,
    );
    expect(
      GlucoseFirstPeak.fromReadings(
        readings([100, 200, 180, 170], minutes: [0, 5, 20, 25]),
      ).peak,
      isNull,
    );
  });
  test(
    'plateau keeps first peak timestamp and missing return stays absent',
    () {
      final result = GlucoseFirstPeak.fromReadings(
        readings([100, 220, 220, 210, 200]),
      );
      expect(result.peak?.date, start.add(const Duration(minutes: 5)));
      expect(result.firstInRangeAfter, isNull);
    },
  );
}
