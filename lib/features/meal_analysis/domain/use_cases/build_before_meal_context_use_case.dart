import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../common/history/latest_reading_at.dart';
import '../../../../common/history/treatment_overlaps_window.dart';
import '../../../../core/domain/model/aaps_prediction_snapshot.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/extended_carb.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../models/before_meal_context.dart';
import '../models/before_meal_windows.dart';
import '../models/extended_carb_plan_context.dart';
import '../models/meal_activity_context.dart';
import '../models/recorded_meal_context.dart';

/// Provider-free entry point shared by future history, foreground and advisor consumers.
class BuildBeforeMealContextUseCase {
  final Future<List<Glucose>> Function(DateTime, DateTime) loadGlucose;
  final Future<List<DeviceStatus>> Function(DateTime, DateTime)
  loadDeviceStatuses;
  final Future<List<Treatment>> Function(DateTime, DateTime) loadTreatments;
  final Future<List<RecordedMealContext>> Function(DateTime, DateTime, int?)
  loadMeals;
  final Future<List<RecordedLowTreatment>> Function(DateTime, DateTime)
  loadLowTreatments;
  final Future<List<MealActivityContext>> Function(DateTime, DateTime, DateTime)
  loadActivities;
  final Future<Duration?> Function(DateTime) loadPodAge;
  final DateTime Function() now;
  final Duration timeout;
  const BuildBeforeMealContextUseCase({
    required this.loadGlucose,
    required this.loadDeviceStatuses,
    required this.loadTreatments,
    required this.loadMeals,
    required this.loadLowTreatments,
    required this.loadActivities,
    required this.loadPodAge,
    required this.now,
    this.timeout = const Duration(seconds: 15),
  });

  Future<BeforeMealContext> call({
    required DateTime asOf,
    required MealMacroSummary? macros,
    int? mealId,
    BeforeMealWindows windows = const BeforeMealWindows(),
  }) async {
    if (asOf.isAfter(now())) {
      throw ArgumentError('Context cutoff cannot be in the future');
    }
    for (final duration in [
      windows.glucose,
      windows.insulin,
      windows.meals,
      windows.activities,
      windows.upcomingActivities,
    ]) {
      if (duration.isNegative) {
        throw ArgumentError('Negative observation window');
      }
    }
    final failures = <BeforeMealSource>{};
    Future<T?> fetch<T>(
      BeforeMealSource source,
      Future<T> Function() action,
    ) async {
      try {
        return await action().timeout(timeout);
      } catch (_) {
        failures.add(source);
        return null;
      }
    }

    final glucoseStart = asOf.subtract(windows.glucose);
    final insulinStart = asOf.subtract(windows.insulin);
    final mealStart = asOf.subtract(windows.meals);
    final treatmentStart = insulinStart.isBefore(mealStart)
        ? insulinStart
        : mealStart;
    final activityStart = asOf.subtract(windows.activities);
    final activityEnd = asOf.add(windows.upcomingActivities);
    final glucoseFuture = fetch(
      BeforeMealSource.glucose,
      () =>
          loadGlucose(glucoseStart.subtract(const Duration(minutes: 5)), asOf),
    );
    final statusFuture = fetch(
      BeforeMealSource.deviceStatus,
      () => loadDeviceStatuses(
        insulinStart.subtract(InsulinBasalSummary.maxSnapshotAge),
        asOf,
      ),
    );
    final treatmentsFuture = fetch(
      BeforeMealSource.treatments,
      () => loadTreatments(treatmentStart, asOf),
    );
    final mealsFuture = fetch(
      BeforeMealSource.meals,
      () => loadMeals(mealStart, asOf, mealId),
    );
    final lowsFuture = fetch(
      BeforeMealSource.lowTreatments,
      () => loadLowTreatments(mealStart, asOf),
    );
    final activitiesFuture = fetch(
      BeforeMealSource.activities,
      () => loadActivities(activityStart, activityEnd, asOf),
    );
    final podFuture = fetch<Duration?>(BeforeMealSource.podAge, () async {
      final age = await loadPodAge(asOf);
      if (age != null && age.isNegative) throw StateError('Negative pod age');
      return age;
    });
    final rawGlucose = await glucoseFuture;
    final glucose =
        rawGlucose == null
              ? null
              : {
                  for (final g in rawGlucose)
                    if (g.type == GlucoseType.cgm &&
                        g.sgv > 0 &&
                        !g.date.isAfter(asOf) &&
                        !g.date.isBefore(
                          glucoseStart.subtract(const Duration(minutes: 5)),
                        ))
                      g.date: g,
                }.values.toList()
          ?..sort((a, b) => a.date.compareTo(b.date));
    final statuses = (await statusFuture)
        ?.where((s) => !s.date.isAfter(asOf))
        .toList();
    final latest = statuses == null
        ? null
        : latestReadingAt(
            statuses,
            asOf,
            (DeviceStatus s) => s.date,
            maxAge: const Duration(minutes: 10),
          );
    final prediction = AapsPredictionSnapshot.decode(
      latest?.aapsPredictionsJson,
    );
    final validPrediction =
        prediction != null && !prediction.calculatedAt.isAfter(asOf)
        ? prediction
        : null;
    final activityFromFuture = latest?.insulinActivityAt?.isAfter(asOf) == true;
    final safeLatest = latest?.copyWith(
      aapsPredictionsJson: validPrediction == null
          ? null
          : latest.aapsPredictionsJson,
      insulinActivity: activityFromFuture ? 0 : latest.insulinActivity,
      hasInsulinActivity: !activityFromFuture && latest.hasInsulinActivity,
      insulinActivityAt: activityFromFuture ? null : latest.insulinActivityAt,
    );
    final treatments =
        (await treatmentsFuture)
            ?.where(
              (t) =>
                  t.isValid &&
                  t.createdAt != null &&
                  treatmentOverlapsWindow(t, treatmentStart, asOf),
            )
            .toSet()
            .toList()
          ?..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    final meals =
        (await mealsFuture)
            ?.where(
              (m) =>
                  m.mealId != mealId &&
                  m.eatenAt.isBefore(asOf) &&
                  !m.eatenAt.isBefore(mealStart),
            )
            .toList()
          ?..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final lows =
        (await lowsFuture)
            ?.where(
              (l) =>
                  l.mealId != mealId &&
                  !l.eatenAt.isAfter(asOf) &&
                  !l.eatenAt.isBefore(mealStart),
            )
            .toList()
          ?..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final activities =
        (await activitiesFuture)
            ?.where(
              (a) =>
                  !a.recordedAt.isAfter(asOf) &&
                  !a.startedAt.isAfter(activityEnd) &&
                  (a.endedAt == null || !a.endedAt!.isBefore(activityStart)),
            )
            .map(
              (a) => MealActivityContext(
                logId: a.logId,
                name: a.name,
                startedAt: a.startedAt,
                endedAt: a.endedAt != null && !a.endedAt!.isAfter(asOf)
                    ? a.endedAt
                    : null,
                recordedAt: a.recordedAt,
                plannedDurationMinutes: a.plannedDurationMinutes,
                percentagePre: a.percentagePre,
                percentagePost: a.percentagePost,
              ),
            )
            .toList()
          ?..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return BeforeMealContext(
      asOf: asOf,
      builtAt: now(),
      mealId: mealId,
      macros: macros,
      windows: windows,
      glucose: glucose,
      glucoseSummary: glucose == null
          ? null
          : GlucosePeriodSummary.calculate(glucose, glucoseStart, asOf),
      latestDeviceStatus: safeLatest,
      predictions: validPrediction,
      basal: statuses == null
          ? null
          : InsulinBasalSummary.calculate(statuses, insulinStart, asOf),
      boluses: treatments == null
          ? null
          : InsulinBolusSummary.fromTreatments(
              treatments: treatments,
              start: insulinStart,
              end: asOf,
            ),
      treatments: treatments,
      extendedCarbPlans: treatments
          ?.whereType<ExtendedCarb>()
          .map((t) => ExtendedCarbPlanContext.at(t, asOf))
          .whereType<ExtendedCarbPlanContext>()
          .toList(),
      priorMeals: meals,
      lowTreatments: lows,
      activities: activities,
      podAge: await podFuture,
      failedSources: failures,
    );
  }
}
