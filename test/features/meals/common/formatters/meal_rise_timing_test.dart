import 'package:diabeatthis/common/history/glucose_rise_summary.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meals/common/formatters/format_meal_rise_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mealTime = DateTime(2026, 9, 9, 20, 0, 24);
  final messages = AppLocalizationsPl();
  Glucose sample(Duration offset, int value) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: mealTime.add(offset),
    sgv: value,
    direction: '',
  );

  test(
    'September 9 onset is a five minute interval, not a millisecond delay',
    () {
      final readings = [
        sample(const Duration(milliseconds: 409), 132),
        sample(const Duration(minutes: 5, milliseconds: 1100), 139),
        sample(const Duration(minutes: 10, milliseconds: -156), 149),
      ];
      final rise = GlucoseRiseSummary.fromReadings(readings);
      expect(rise.onsetIntervalEnd, readings[1].date);
      expect(formatMealRiseTiming(rise, mealTime, messages), '0–5 min');
    },
  );

  test(
    'a later rise uses its actual interval rather than confirmation time',
    () {
      final readings = [
        sample(Duration.zero, 100),
        sample(const Duration(minutes: 5), 100),
        sample(const Duration(minutes: 10), 99),
        sample(const Duration(minutes: 15), 107),
        sample(const Duration(minutes: 20), 116),
      ];
      final rise = GlucoseRiseSummary.fromReadings(readings);
      expect(rise.startedAt, readings[2].date);
      expect(rise.onsetIntervalEnd, readings[3].date);
      expect(formatMealRiseTiming(rise, mealTime, messages), '10–15 min');
    },
  );

  test('missing evidence does not invent an onset interval', () {
    final rise = GlucoseRiseSummary.fromReadings([]);
    expect(rise.onsetIntervalEnd, isNull);
    expect(formatMealRiseTiming(rise, mealTime, messages), '—');
  });
}
