import 'package:diabeatthis/common/history/load_nightscout_day_context_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_statistics_nightscout.dart';

void main() {
  final date = DateTime(2026, 11, 5);
  final now = DateTime(2026, 11, 7, 12);
  test(
    'Nightscout alone provides same day/night facts with unknown local context',
    () async {
      final ns = DayStatisticsNightscout(date);
      final result = await LoadNightscoutDayContextUseCase(ns, now: () => now)(
        date: date,
      );
      expect(result.glucose!.mean, 120);
      expect(result.nightGlucose!.mean, 120);
      expect(result.boluses!.units, 2);
      expect(result.nightBoluses!.units, 1);
      expect(result.meals, isNull);
      expect(result.activities, isNull);
      expect(result.lowTreatments, isNull);
      expect(result.failedSources, isEmpty);
      expect(ns.glucoseWindows.single, (
        DateTime(2026, 11, 4, 21, 55),
        DateTime(2026, 11, 6).subtract(const Duration(microseconds: 1)),
      ));
      expect(ns.sensorAsOf, [DateTime(2026, 11, 6)]);
      expect(ns.podAsOf, [DateTime(2026, 11, 6)]);
    },
  );
  for (final source in [
    DayDataSource.glucose,
    DayDataSource.treatments,
    DayDataSource.deviceStatus,
  ]) {
    test('missing $source does not discard other available sources', () async {
      final ns = DayStatisticsNightscout(date)
        ..failGlucose = source == DayDataSource.glucose
        ..failTreatments = source == DayDataSource.treatments
        ..failDevices = source == DayDataSource.deviceStatus;
      final result = await LoadNightscoutDayContextUseCase(ns, now: () => now)(
        date: date,
      );
      expect(result.failedSources, {source});
      expect(
        result.glucose?.mean,
        source == DayDataSource.glucose ? isNull : 120,
      );
      expect(
        result.boluses?.units,
        source == DayDataSource.treatments ? isNull : 2,
      );
      expect(result.sensorAge, const Duration(days: 1, minutes: 30));
      expect(result.meals, isNull);
    });
  }
  test(
    'empty readings remain unknown and current-day queries stop at now',
    () async {
      final ns = DayStatisticsNightscout(DateTime(2026, 11, 7), empty: true);
      final result = await LoadNightscoutDayContextUseCase(ns, now: () => now)(
        date: DateTime(2026, 11, 7),
      );
      expect(result.glucose!.mean, isNull);
      expect(result.glucose!.window.observed, Duration.zero);
      expect(result.sensorAge, isNull);
      expect(result.isComplete, isFalse);
      expect(ns.glucoseWindows.single.$2, now);
    },
  );
}
