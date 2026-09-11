import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/history/insulin_basal_summary.dart';
import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_summary_snapshot_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'snapshot preserves aggregates, source gaps and night boundaries without raw readings',
    () {
      final start = DateTime(2026, 9, 10);
      final end = DateTime(2026, 9, 11);
      final glucose = GlucosePeriodSummary.calculate(
        [
          Glucose(
            externalId: null,
            source: GlucoseSource.cloud,
            direction: 'Flat',
            sgv: 100,
            date: start,
          ),
          Glucose(
            externalId: null,
            source: GlucoseSource.cloud,
            direction: 'Flat',
            sgv: 200,
            date: start.add(const Duration(minutes: 5)),
          ),
        ],
        start,
        end,
      );
      final day = DayContext(
        start: start,
        asOf: end,
        builtAt: end,
        glucose: glucose,
        nightGlucose: null,
        basal: InsulinBasalSummary(
          units: 4,
          profileUnits: 5,
          addedUnits: 1,
          reducedUnits: 2,
          coveredDuration: const Duration(hours: 12),
          duration: const Duration(days: 1),
          gaps: [],
        ),
        boluses: const InsulinBolusSummary(
          manualCount: 1,
          manualUnits: 2,
          otherCount: 4,
          otherUnits: 1,
        ),
        nightBoluses: null,
        meals: const DayMealSummary(
          count: 2,
          plannedFallbackCount: 0,
          missingSnapshotCount: 0,
          netCarbs: 40,
          protein: 20,
          fat: 10,
        ),
        lowTreatments: [],
        activities: [],
        failedSources: {DayDataSource.sensorAge},
      );
      final snapshot = const BuildDaySummarySnapshotUseCase()(
        day,
        meals: [],
        lows: null,
      );
      expect(snapshot.metrics[DaySummaryMetric.glucoseMean], 150);
      expect(snapshot.metrics[DaySummaryMetric.glucoseHighPercent], 50);
      expect(snapshot.metrics[DaySummaryMetric.totalInsulinUnits], 7);
      expect(snapshot.metrics[DaySummaryMetric.basalCoveragePercent], 50);
      expect(snapshot.metrics[DaySummaryMetric.lowTreatmentCarbsGrams], 0);
      expect(snapshot.metrics[DaySummaryMetric.nightGlucoseMean], isNull);
      expect(
        snapshot.limitations,
        containsAll([
          'glucose',
          'basal',
          'nightGlucose',
          'lowTreatmentReview',
          'sensorAge',
        ]),
      );
      expect(snapshot.nightStart, DateTime(2026, 9, 9, 22));
      expect(snapshot.nightEnd, DateTime(2026, 9, 10, 6));
      expect(snapshot.encode(), isNot(contains('readings')));
      expect(
        DaySummarySnapshot.decode(snapshot.encode()).metrics,
        snapshot.metrics,
      );
    },
  );
}
