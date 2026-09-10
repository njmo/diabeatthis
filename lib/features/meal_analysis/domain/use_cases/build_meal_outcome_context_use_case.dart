import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../common/history/treatment_overlaps_window.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/extended_carb.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../models/extended_carb_overlap.dart';
import '../models/meal_activity_observation.dart';
import '../models/meal_outcome_context.dart';
import '../models/recorded_meal_context.dart';

/// Builds from already fetched history, so the existing chart and future
/// consumers can share inputs without downloading overlapping windows twice.
class BuildMealOutcomeContextUseCase {
  const BuildMealOutcomeContextUseCase();

  MealOutcomeContext call({
    required DateTime mealTime,
    required Duration window,
    required DateTime asOf,
    required DateTime builtAt,
    required DateTime treatmentHistoryStart,
    required List<Glucose> glucose,
    required List<DeviceStatus> deviceStatuses,
    required List<Treatment> treatments,
    required List<RecordedLowTreatment> lowTreatments,
    required List<MealActivityObservation> activities,
    required List<RecordedMealContext>? subsequentMeals,
    int? mealId,
  }) {
    if (window.isNegative ||
        asOf.isBefore(mealTime) ||
        builtAt.isBefore(asOf) ||
        treatmentHistoryStart.isAfter(mealTime)) {
      throw ArgumentError('Invalid observation bounds');
    }
    final expected = mealTime.add(window);
    final end = asOf.isBefore(expected) ? asOf : expected;
    bool inWindow(DateTime at) => !at.isBefore(mealTime) && !at.isAfter(end);
    final readings = {
      for (final g in glucose)
        if (g.type == GlucoseType.cgm &&
            g.sgv > 0 &&
            !g.date.isAfter(end) &&
            !g.date.isBefore(mealTime.subtract(const Duration(minutes: 5))))
          g.date: g,
    }.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    final statuses =
        deviceStatuses
            .where(
              (s) =>
                  !s.date.isAfter(end) &&
                  !s.date.isBefore(
                    mealTime.subtract(InsulinBasalSummary.maxSnapshotAge),
                  ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final history = treatments
        .where(
          (t) =>
              t.isValid &&
              t.createdAt != null &&
              treatmentOverlapsWindow(t, treatmentHistoryStart, end),
        )
        .toSet()
        .toList();
    final events =
        history.where((t) => treatmentOverlapsWindow(t, mealTime, end)).toList()
          ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    final lows =
        lowTreatments
            .where((l) => l.mealId != mealId && inWindow(l.eatenAt))
            .toList()
          ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final observedActivities =
        activities
            .where(
              (a) =>
                  end.isAfter(mealTime) &&
                  a.startedAt.isBefore(end) &&
                  (a.endedAt == null || a.endedAt!.isAfter(mealTime)),
            )
            .map(
              (a) => MealActivityObservation(
                logId: a.logId,
                name: a.name,
                startedAt: a.startedAt,
                endedAt: a.endedAt != null && !a.endedAt!.isAfter(end)
                    ? a.endedAt
                    : null,
                intensity: a.intensity,
              ),
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final meals =
        subsequentMeals
            ?.where((m) => m.mealId != mealId && inWindow(m.eatenAt))
            .toList()
          ?..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final overlaps =
        history
            .whereType<ExtendedCarb>()
            .map((t) => ExtendedCarbOverlap.between(t, mealTime, end))
            .whereType<ExtendedCarbOverlap>()
            .toList()
          ..sort((a, b) => a.overlapStart.compareTo(b.overlapStart));
    return MealOutcomeContext(
      mealTime: mealTime,
      observedUntil: end,
      expectedUntil: expected,
      builtAt: builtAt,
      glucoseSummary: GlucosePeriodSummary.calculate(readings, mealTime, end),
      basal: InsulinBasalSummary.calculate(statuses, mealTime, end),
      boluses: InsulinBolusSummary.fromTreatments(
        treatments: history,
        start: mealTime,
        end: end,
      ),
      glucose: readings,
      deviceStatuses: statuses,
      treatments: events,
      lowTreatments: lows,
      activities: observedActivities,
      subsequentMeals: meals,
      extendedCarbs: overlaps,
      treatmentHistoryStart: treatmentHistoryStart,
    );
  }
}
