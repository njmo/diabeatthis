import '../../../../common/history/bolus_wizard_grouping.dart';
import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../../core/logger/logger.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../models/day_activity_summary.dart';
import '../models/day_analysis_window.dart';
import '../models/day_context.dart';
import '../models/day_meal_summary.dart';

class BuildDayContextUseCase with Logging {
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

  Future<DayContext> call({DateTime? date}) async {
    final window = DayAnalysisWindow(now: now(), date: date);
    final start = window.start;
    final asOf = window.end;
    final queryEnd = window.queryEnd;
    final nightStart = window.nightStart;
    final nightEnd = window.nightEnd;
    final failures = <DayDataSource>{};
    Future<T?> fetch<T>(
      DayDataSource source,
      Future<T> Function() action,
    ) async {
      try {
        return await action().timeout(timeout);
      } catch (error) {
        logW('Day context ${source.name} failed: ${error.runtimeType}');
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
              queryEnd,
            ),
          );
    final glucoseFuture = fetch(
      DayDataSource.glucose,
      () => loadGlucose(
        nightStart.subtract(const Duration(minutes: 5)),
        queryEnd,
      ),
    );
    final treatmentsFuture = fetch(
      DayDataSource.treatments,
      () => loadTreatments(nightStart, queryEnd),
    );
    final mealsFuture = fetch(
      DayDataSource.meals,
      () => loadMeals(start, queryEnd),
    );
    final lowsFuture = fetch(
      DayDataSource.lowTreatments,
      () => loadLowTreatments(start, queryEnd),
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
      Future<Duration?> readAge() async {
        final age = await load(asOf).timeout(timeout);
        if (age != null && age.isNegative) {
          throw ArgumentError('Negative device age');
        }
        return age;
      }

      try {
        return await readAge();
      } on ArgumentError {
        failures.add(source);
        return null;
      } on FormatException {
        failures.add(source);
        return null;
      } catch (error) {
        logW('Retrying day context ${source.name}: ${error.runtimeType}');
        // One retry handles transient transport/startup failures. An empty
        // successful response stays unknown and is not retried.
        return fetch<Duration?>(source, readAge);
      }
    }

    final sensorAgeFuture = fetchAge(DayDataSource.sensorAge, loadSensorAge);
    final podAgeFuture = fetchAge(DayDataSource.podAge, loadPodAge);
    final glucose = (await glucoseFuture)
        ?.where((g) => !g.date.isAfter(queryEnd))
        .toList();
    final treatments = (await treatmentsFuture)
        ?.where((t) => t.createdAt == null || !t.createdAt!.isAfter(queryEnd))
        .toList();
    final meals = await mealsFuture;
    final lows = (await lowsFuture)
        ?.where(
          (low) =>
              !low.eatenAt.isBefore(start) && !low.eatenAt.isAfter(queryEnd),
        )
        .toList();
    final activities = await activitiesFuture;
    final sensorAge = await sensorAgeFuture;
    final podAge = await podAgeFuture;
    final statuses = (await statusesFuture)
        ?.where((s) => !s.date.isAfter(queryEnd))
        .toList();
    final wizardGroups = BolusWizardGrouping(treatments ?? const []);
    return DayContext(
      carbEntries: treatments
          ?.whereType<Treat>()
          .where(
            (entry) =>
                entry.isValid &&
                entry.carbs > 0 &&
                !wizardGroups.isRelated(entry) &&
                !entry.createdAt.isBefore(start),
          )
          .toList(),
      wizards: treatments
          ?.whereType<BolusWizard>()
          .where(
            (wizard) => wizard.isValid && !wizard.createdAt.isBefore(start),
          )
          .toList(),
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
