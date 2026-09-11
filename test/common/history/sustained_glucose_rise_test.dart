import 'package:diabeatthis/common/history/glucose_rise_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 9, 20);
  Glucose reading(int minute, int value) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: start.add(Duration(minutes: minute)),
    sgv: value,
    direction: '',
  );

  test(
    'September 9 meal detects rise despite uneven rate and CGM timestamp jitter',
    () {
      final readings = [
        reading(0, 132).copyWith(date: DateTime(2026, 9, 9, 20, 0, 24, 409)),
        reading(5, 139).copyWith(date: DateTime(2026, 9, 9, 20, 5, 25, 100)),
        reading(10, 149).copyWith(date: DateTime(2026, 9, 9, 20, 10, 23, 844)),
        reading(15, 158).copyWith(date: DateTime(2026, 9, 9, 20, 15, 24, 141)),
        reading(20, 167).copyWith(date: DateTime(2026, 9, 9, 20, 20, 24, 51)),
        reading(25, 173).copyWith(date: DateTime(2026, 9, 9, 20, 25, 25, 137)),
      ];
      // Confirmation must be available from the first three recorded samples.
      final result = GlucoseRiseSummary.fromReadings(readings.take(3).toList());
      expect(result.startedAt, readings.first.date);
      expect(result.hasObservation, isTrue);
      expect(
        GlucoseRiseSummary.fromReadings(readings).startedAt,
        readings.first.date,
      );
    },
  );

  test(
    'a single jump followed by weak drift does not establish sustained onset',
    () {
      final result = GlucoseRiseSummary.fromReadings([
        reading(0, 100),
        reading(5, 140),
        reading(10, 141),
        reading(15, 142),
      ]);
      expect(result.startedAt, isNull);
      expect(result.hasObservation, isTrue);
    },
  );

  test('a later acceleration is not diluted by an earlier slow drift', () {
    final result = GlucoseRiseSummary.fromReadings([
      reading(0, 100),
      reading(5, 105),
      reading(10, 110),
      reading(15, 115),
      reading(20, 120),
      reading(25, 128),
      reading(30, 137),
    ]);
    expect(result.startedAt, start.add(const Duration(minutes: 20)));
  });

  test('a fall resets onset and no window crosses a missing CGM sample', () {
    final result = GlucoseRiseSummary.fromReadings([
      reading(0, 100),
      reading(5, 109),
      reading(10, 105),
      reading(15, 113),
      reading(25, 130),
      reading(30, 138),
      reading(35, 147),
    ]);
    expect(result.startedAt, start.add(const Duration(minutes: 25)));
  });

  test('two samples or a short burst cannot confirm sustained onset', () {
    expect(
      GlucoseRiseSummary.fromReadings([
        reading(0, 100),
        reading(6, 130),
      ]).startedAt,
      isNull,
    );
    expect(
      GlucoseRiseSummary.fromReadings([
        reading(0, 100),
        reading(3, 110),
        reading(6, 120),
      ]).startedAt,
      isNull,
    );
  });
}
