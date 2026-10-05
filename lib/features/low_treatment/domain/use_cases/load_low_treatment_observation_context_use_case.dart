import '../../../../core/domain/model/stress_event.dart';
import '../../../../core/logger/logger.dart';
import '../../../meal_analysis/domain/models/meal_activity_context.dart';
import '../models/low_treatment_observation_context_data.dart';

/// Optional local context must not delay or change the request supplied by AAPS.
class LoadLowTreatmentObservationContextUseCase with Logging {
  final Future<List<MealActivityContext>> Function(DateTime, DateTime, DateTime)
  loadActivities;
  final Future<List<StressEvent>> Function(DateTime, DateTime) loadStress;
  final Duration upcomingWindow;
  final Duration stressLookback;
  final Duration timeout;

  const LoadLowTreatmentObservationContextUseCase({
    required this.loadActivities,
    required this.loadStress,
    this.upcomingWindow = const Duration(hours: 1),
    this.stressLookback = const Duration(hours: 3),
    this.timeout = const Duration(seconds: 2),
  });

  Future<LowTreatmentObservationContextData> call(DateTime asOf) async {
    Future<List<T>> optional<T>(
      String source,
      Future<List<T>> Function() load,
    ) async {
      try {
        return await load().timeout(timeout);
      } catch (error) {
        logW('Carb reminder $source context unavailable: ${error.runtimeType}');
        return [];
      }
    }

    final end = asOf.add(upcomingWindow);
    final activityRead = optional(
      'activity',
      () => loadActivities(asOf.subtract(const Duration(days: 1)), end, asOf),
    );
    final stressRead = optional(
      'stress',
      () => loadStress(asOf.subtract(stressLookback), asOf),
    );
    final activities =
        (await activityRead)
            .where(
              (a) =>
                  !a.recordedAt.isAfter(asOf) &&
                  a.startedAt.isBefore(end) &&
                  !a.startedAt.isBefore(
                    asOf.subtract(const Duration(days: 1)),
                  ) &&
                  (a.endedAt == null || a.endedAt!.isAfter(asOf)),
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    // Prefer the nearest upcoming plan; otherwise expose the latest unclosed log.
    // The notification names the recorded start, not a confirmed ongoing effort.
    final activity =
        activities.where((a) => !a.startedAt.isBefore(asOf)).firstOrNull ??
        activities.lastOrNull;
    final stress =
        (await stressRead)
            .where(
              (s) =>
                  !s.occurredAt.isAfter(asOf) &&
                  (!s.occurredAt.isBefore(asOf.subtract(stressLookback)) ||
                      (s.endedAt != null && s.endedAt!.isAfter(asOf))),
            )
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final latestStress = stress.lastOrNull;
    return LowTreatmentObservationContextData(
      activityName: activity?.name,
      activityStartsAt: activity?.startedAt,
      stressLevel: latestStress?.stressLevel,
      stressObservedAt: latestStress?.occurredAt,
    );
  }
}
