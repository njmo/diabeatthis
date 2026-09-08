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
