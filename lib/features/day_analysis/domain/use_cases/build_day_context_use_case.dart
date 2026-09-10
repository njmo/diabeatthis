import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../models/day_activity_summary.dart';
import '../models/day_context.dart';
import '../models/day_meal_summary.dart';

class BuildDayContextUseCase {
  final Future<List<Glucose>> Function(DateTime, DateTime) loadGlucose;
  final Future<List<Treatment>> Function(DateTime, DateTime) loadTreatments;
  final Future<DayMealSummary> Function(DateTime, DateTime) loadMeals;
  final Future<List<RecordedLowTreatment>> Function(DateTime, DateTime)
  loadLowTreatments;
  final Future<List<DayActivitySummary>> Function(DateTime, DateTime)
  loadActivities;
  final Future<Duration?> Function(DateTime)? loadSensorAge;
  final Future<Duration?> Function(DateTime)? loadPodAge;
  final Future<List<DeviceStatus>> Function(DateTime, DateTime)?
  loadDeviceStatuses;
  final DateTime Function() now;
  final Duration timeout;

  const BuildDayContextUseCase({
    required this.loadGlucose,
    required this.loadTreatments,
    required this.loadMeals,
    required this.loadLowTreatments,
    required this.loadActivities,
    required this.now,
    this.loadDeviceStatuses,
    this.loadSensorAge,
    this.loadPodAge,
    this.timeout = const Duration(seconds: 15),
  });

  Future<DayContext> call() async {
    final asOf = now().toLocal();
    final start = DateTime(asOf.year, asOf.month, asOf.day);
    // Explicit clock window, not an inferred sleep interval.
    final nightStart = DateTime(asOf.year, asOf.month, asOf.day - 1, 22);
    final morning = DateTime(asOf.year, asOf.month, asOf.day, 6);
    final nightEnd = asOf.isBefore(morning) ? asOf : morning;
    final failures = <DayDataSource>{};
    Future<T?> fetch<T>(
      DayDataSource source,
      Future<T> Function() action,
    ) async {
      try {
        return await action().timeout(timeout);
      } catch (_) {
        failures.add(source);
        return null;
      }
    }

    final statusesFuture = loadDeviceStatuses == null
        ? Future<List<DeviceStatus>?>.value(null)
        : fetch(
            DayDataSource.deviceStatus,
            () => loadDeviceStatuses!(
              nightStart.subtract(InsulinBasalSummary.maxSnapshotAge),
              asOf,
            ),
          );
    final glucoseFuture = fetch(
      DayDataSource.glucose,
      () => loadGlucose(nightStart.subtract(const Duration(minutes: 5)), asOf),
    );
    final treatmentsFuture = fetch(
      DayDataSource.treatments,
      () => loadTreatments(nightStart, asOf),
    );
    final mealsFuture = fetch(
      DayDataSource.meals,
      () => loadMeals(start, asOf),
    );
    final lowsFuture = fetch(
      DayDataSource.lowTreatments,
      () => loadLowTreatments(start, asOf),
    );
    final activitiesFuture = fetch(
      DayDataSource.activities,
      () => loadActivities(start, asOf),
    );
    Future<Duration?> fetchAge(
      DayDataSource source,
      Future<Duration?> Function(DateTime)? load,
    ) async {
      if (load == null) return null;
      return fetch<Duration?>(source, () async {
        final age = await load(asOf);
        if (age != null && age.isNegative) {
          throw StateError('Negative device age');
        }
        return age;
      });
    }

    final sensorAgeFuture = fetchAge(DayDataSource.sensorAge, loadSensorAge);
    final podAgeFuture = fetchAge(DayDataSource.podAge, loadPodAge);
    final glucose = await glucoseFuture;
    final treatments = await treatmentsFuture;
    final meals = await mealsFuture;
    final lows = await lowsFuture;
    final activities = await activitiesFuture;
    final sensorAge = await sensorAgeFuture;
    final podAge = await podAgeFuture;
    final statuses = await statusesFuture;
    return DayContext(
      basal: statuses == null
          ? null
          : InsulinBasalSummary.calculate(statuses, start, asOf),
      nightBasal: statuses == null
          ? null
          : InsulinBasalSummary.calculate(statuses, nightStart, nightEnd),
      sensorAge: sensorAge,
      podAge: podAge,
      start: start,
      asOf: asOf,
      builtAt: now(),
      glucose: glucose == null
          ? null
          : GlucosePeriodSummary.calculate(glucose, start, asOf),
      nightGlucose: glucose == null
          ? null
          : GlucosePeriodSummary.calculate(glucose, nightStart, nightEnd),
      boluses: treatments == null
          ? null
          : InsulinBolusSummary.fromTreatments(
              treatments: treatments,
              start: start,
              end: asOf,
            ),
      nightBoluses: treatments == null
          ? null
          : InsulinBolusSummary.fromTreatments(
              treatments: treatments,
              start: nightStart,
              end: nightEnd,
            ),
      meals: meals,
      lowTreatments: lows,
      activities: activities,
      failedSources: failures,
    );
  }
}
