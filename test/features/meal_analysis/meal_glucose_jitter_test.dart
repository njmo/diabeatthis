import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/history/glucose_rise_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meal_analysis/domain/services/meal_glucose_observation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'completed regular CGM stream allows a negative rise result despite jitter',
    () {
      final start = DateTime(2026, 9, 9, 20);
      final samples = [0, 301, 602, 903]
          .map(
            (s) => Glucose(
              externalId: null,
              source: GlucoseSource.cloud,
              date: start.add(Duration(seconds: s)),
              sgv: 120,
              direction: 'Flat',
            ),
          )
          .toList();
      final window = GlucosePeriodSummary.calculate(
        samples,
        start,
        start.add(const Duration(minutes: 20)),
      ).window;
      final rise = GlucoseRiseSummary.fromReadings(window.readings);
      expect(window.missing, const Duration(seconds: 3));
      expect(
        hasCompleteMealRiseObservation(rise, window, complete: true),
        isTrue,
      );
      expect(
        hasCompleteMealRiseObservation(rise, window, complete: false),
        isFalse,
      );
    },
  );
}
