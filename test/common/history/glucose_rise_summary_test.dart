import 'package:diabeatthis/common/history/glucose_rise_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 8, 12);
  Glucose reading(int minute, int value) => Glucose(
    externalId: '$minute',
    source: GlucoseSource.cloud,
    date: start.add(Duration(minutes: minute)),
    sgv: value,
    direction: 'Flat',
  );

  test('timestamp jitter does not erase a valid observation', () {
    final values = [
      reading(0, 100),
      reading(
        5,
        102,
      ).copyWith(date: start.add(const Duration(minutes: 5, seconds: 1))),
      reading(
        10,
        104,
      ).copyWith(date: start.add(const Duration(minutes: 10, seconds: 2))),
    ];
    final result = GlucoseRiseSummary.fromReadings(values);
    expect(result.hasObservation, isTrue);
    expect(result.startedAt, isNull);
  });

  test(
    'detects sustained rise with jitter but rejects gaps over six minutes',
    () {
      final result = GlucoseRiseSummary.fromReadings([
        reading(0, 100),
        reading(
          5,
          111,
        ).copyWith(date: start.add(const Duration(minutes: 5, seconds: 1))),
        reading(
          10,
          122,
        ).copyWith(date: start.add(const Duration(minutes: 10, seconds: 2))),
      ]);
      expect(result.startedAt, start);
      final gap = GlucoseRiseSummary.fromReadings([
        reading(0, 100),
        reading(
          6,
          120,
        ).copyWith(date: start.add(const Duration(minutes: 6, seconds: 1))),
        reading(11, 140),
      ]);
      expect(gap.hasObservation, isFalse);
      expect(gap.startedAt, isNull);
    },
  );

  test('finds the beginning of a sustained rise after an initial fall', () {
    final result = GlucoseRiseSummary.fromReadings([
      reading(0, 120),
      reading(5, 110),
      reading(10, 120),
      reading(15, 130),
      reading(20, 150),
    ]);
    expect(result.startedAt, start.add(const Duration(minutes: 5)));
  });

  test('a single jump or a slow rise is not a sustained rapid rise', () {
    for (final values in [
      [reading(0, 100), reading(5, 140), reading(10, 140)],
      [reading(0, 100), reading(5, 105), reading(10, 110)],
    ]) {
      final result = GlucoseRiseSummary.fromReadings(values);
      expect(result.startedAt, isNull);
      expect(result.hasObservation, isTrue);
    }
  });

  test('gaps do not imply a rise and an insufficient window stays unknown', () {
    final result = GlucoseRiseSummary.fromReadings([
      reading(0, 100),
      reading(5, 110),
      reading(20, 150),
      reading(25, 160),
    ]);
    expect(result.startedAt, isNull);
    expect(result.hasObservation, isFalse);
    expect(GlucoseRiseSummary.fromReadings([]).hasObservation, isFalse);
  });

  test('finds a later observed rise after a gap', () {
    final result = GlucoseRiseSummary.fromReadings([
      reading(0, 100),
      reading(20, 150),
      reading(25, 160),
      reading(30, 170),
    ]);
    expect(result.startedAt, start.add(const Duration(minutes: 20)));
  });
}
