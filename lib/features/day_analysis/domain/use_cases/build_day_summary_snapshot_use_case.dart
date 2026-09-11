import '../../../low_treatment/domain/models/low_treatment_review_entry.dart';
import '../models/day_analysis_window.dart';
import '../models/day_context.dart';
import '../models/day_meal_review_entry.dart';
import '../models/day_summary_snapshot.dart';

class BuildDaySummarySnapshotUseCase {
  const BuildDaySummarySnapshotUseCase();

  DaySummarySnapshot call(
    DayContext day, {
    required List<DayMealReviewEntry>? meals,
    required List<LowTreatmentReviewEntry>? lows,
  }) {
    final window = DayAnalysisWindow(now: day.asOf, date: day.start);
    final g = day.glucose;
    final n = day.nightGlucose;
    final limitations = day.failedSources.map((source) => source.name).toSet();
    if (g == null || !g.hasContinuousReadings) limitations.add('glucose');
    if (n == null || !n.hasContinuousReadings) limitations.add('nightGlucose');
    if (day.basal == null || day.basal!.coverage < 1) limitations.add('basal');
    if (day.nightBasal == null || day.nightBasal!.coverage < 1) {
      limitations.add('nightBasal');
    }
    if (day.meals == null ||
        day.meals!.missingSnapshotCount > 0 ||
        day.meals!.plannedFallbackCount > 0) {
      limitations.add('meals');
    }
    if (day.lowTreatments == null ||
        day.lowTreatments!.any((low) => low.netCarbsGrams == null)) {
      limitations.add('lowTreatments');
    }
    if (day.activities == null) limitations.add('activities');
    if (day.boluses == null || day.nightBoluses == null) {
      limitations.add('treatments');
    }
    if (day.sensorAge == null) limitations.add('sensorAge');
    if (day.podAge == null) limitations.add('podAge');
    if (meals == null) limitations.add('mealReview');
    if (lows == null) limitations.add('lowTreatmentReview');
    return DaySummarySnapshot(
      nightStart: window.nightStart,
      nightEnd: window.nightEnd,
      dayKey: daySummaryKey(day.start),
      asOf: day.asOf,
      builtAt: day.builtAt,
      utcOffsetMinutes: day.start.timeZoneOffset.inMinutes,
      metrics: {
        DaySummaryMetric.totalInsulinUnits:
            day.basal == null || day.boluses == null
            ? null
            : day.basal!.units + day.boluses!.units,
        DaySummaryMetric.glucoseMean: g?.mean,
        DaySummaryMetric.glucoseLowPercent: g?.window.percent(
          g.window.belowRange,
        ),
        DaySummaryMetric.glucoseInRangePercent: g?.window.percent(
          g.window.inRange,
        ),
        DaySummaryMetric.glucoseHighPercent: g?.window.percent(
          g.window.aboveRange,
        ),
        DaySummaryMetric.glucoseMax: g?.window.peak?.sgv,
        DaySummaryMetric.glucoseCoveragePercent: g?.coveragePercent,
        DaySummaryMetric.nightGlucoseMean: n?.mean,
        DaySummaryMetric.nightInRangePercent: n?.window.percent(
          n.window.inRange,
        ),
        DaySummaryMetric.nightGlucoseCoveragePercent: n?.coveragePercent,
        DaySummaryMetric.basalUnits: day.basal?.units,
        DaySummaryMetric.basalAddedUnits: day.basal?.addedUnits,
        DaySummaryMetric.basalReducedUnits: day.basal?.reducedUnits,
        DaySummaryMetric.basalCoveragePercent: day.basal == null
            ? null
            : day.basal!.coverage * 100,
        DaySummaryMetric.bolusUnits: day.boluses?.units,
        DaySummaryMetric.smbUnits: day.boluses?.otherUnits,
        DaySummaryMetric.smbCount: day.boluses?.otherCount,
        DaySummaryMetric.nightBasalUnits: day.nightBasal?.units,
        DaySummaryMetric.nightBasalCoveragePercent: day.nightBasal == null
            ? null
            : day.nightBasal!.coverage * 100,
        DaySummaryMetric.nightBolusUnits: day.nightBoluses?.units,
        DaySummaryMetric.nightSmbUnits: day.nightBoluses?.otherUnits,
        DaySummaryMetric.nightSmbCount: day.nightBoluses?.otherCount,
        DaySummaryMetric.mealCount: day.meals?.count,
        DaySummaryMetric.netCarbsGrams: day.meals?.netCarbs,
        DaySummaryMetric.proteinGrams: day.meals?.protein,
        DaySummaryMetric.fatGrams: day.meals?.fat,
        DaySummaryMetric.lowTreatmentCount: day.lowTreatments?.length,
        DaySummaryMetric.lowTreatmentCarbsGrams:
            day.lowTreatments == null ||
                day.lowTreatments!.any((low) => low.netCarbsGrams == null)
            ? null
            : day.lowTreatments!.fold<double>(
                0,
                (sum, low) => sum + low.netCarbsGrams!,
              ),
        DaySummaryMetric.activityMinutes: day.activities?.fold<int>(
          0,
          (sum, activity) => sum + activity.observedDuration.inMinutes,
        ),
        DaySummaryMetric.sensorAgeMinutes: day.sensorAge?.inMinutes,
        DaySummaryMetric.podAgeMinutes: day.podAge?.inMinutes,
      },
      limitations: limitations.toList()..sort(),
      review: [
        for (final entry in meals ?? <DayMealReviewEntry>[])
          for (final wizard in entry.wizards)
            DaySummaryReviewRecord(
              kind: DaySummaryReviewKind.meal,
              occurredAt: wizard.createdAt,
              mealId: entry.meal?.id,
              sourceId: wizard.nightscoutObjectId ?? wizard.localId,
              resolution: entry.meal == null
                  ? DaySummaryResolution.unresolved
                  : DaySummaryResolution.linked,
            ),
        for (final entry in lows ?? <LowTreatmentReviewEntry>[])
          if (entry.event != null)
            DaySummaryReviewRecord(
              kind: DaySummaryReviewKind.lowTreatment,
              occurredAt: entry.event!.createdAt,
              mealId: entry.recorded?.mealId,
              sourceId: entry.event!.externalId,
              resolution: entry.dismissed
                  ? DaySummaryResolution.dismissed
                  : entry.recorded == null
                  ? DaySummaryResolution.unresolved
                  : DaySummaryResolution.linked,
            ),
      ],
    );
  }
}
