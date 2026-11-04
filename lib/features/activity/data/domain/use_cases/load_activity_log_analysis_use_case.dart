import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/domain/model/stress_event_treatment.dart';
import '../../../../../core/domain/model/temporary_target.dart';
import '../../../../../core/drift/database_impl.dart' show MealData;
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../meals/data/domain/use_cases/load_meal_details_use_case.dart';
import '../../../../meals/data/models/meal_details_data.dart';
import '../../models/activity_log_analysis_data.dart';
import '../../models/activity_log_details_data.dart';

part 'load_activity_log_analysis_use_case.g.dart';

@Riverpod(keepAlive: true)
LoadActivityLogAnalysisUseCase loadActivityLogAnalysisUseCase(Ref ref) {
  return LoadActivityLogAnalysisUseCase(ref: ref);
}

class LoadActivityLogAnalysisUseCase {
  final Ref ref;

  const LoadActivityLogAnalysisUseCase({required this.ref});

  Future<ActivityLogAnalysisData?> call(
    ActivityLogDetailsData log, {
    bool includeContext = false,
  }) async {
    final activityEnd = log.endedAt;
    if (activityEnd == null) {
      return null;
    }

    final chartStart = log.startedAt.subtract(const Duration(minutes: 30));
    final chartEnd = activityEnd.add(
      includeContext ? const Duration(hours: 3) : const Duration(minutes: 30),
    );
    final treatmentFetchStart = chartStart.subtract(const Duration(hours: 4));
    final preMealStart = log.startedAt.subtract(const Duration(hours: 3));

    final glucoseRepository = await ref.read(
      glucoseHistoryRepositoryProvider.future,
    );
    final treatmentRepository = await ref.read(
      treatmentsHistoryRepositoryProvider.future,
    );
    final deviceStatusRepository = await ref.read(
      deviceStatusHistoryRepositoryProvider.future,
    );
    final glucose = await glucoseRepository.fetchGlucoseBetween(
      chartStart,
      chartEnd,
    );
    final treatments = await treatmentRepository.fetchTreatmentsBetween(
      treatmentFetchStart,
      chartEnd,
    );
    final deviceStatuses = await deviceStatusRepository
        .fetchDeviceStatusBetween(chartStart, chartEnd);
    final deviceStatusAtStart = await deviceStatusRepository
        .fetchLastDeviceStatusBefore(log.startedAt);

    final chartTreatments = treatments.where((treatment) {
      final createdAt = treatment.createdAt;
      if (createdAt == null || !treatment.isValid) return false;
      if (treatment is StressEventTreatment &&
          treatment.event.endedAt != null) {
        return !createdAt.isAfter(chartEnd) &&
            !treatment.event.endedAt!.isBefore(chartStart);
      }
      return _isBetween(createdAt, chartStart, chartEnd);
    }).toList();

    final activityTargets = treatments.whereType<TemporaryTarget>().where((
      target,
    ) {
      if (target.targetTop != ActivityLogAnalysisData.activityTargetTop) {
        return false;
      }
      final targetEnd = target.createdAt.add(
        Duration(minutes: target.duration),
      );
      return target.createdAt.isBefore(chartEnd) &&
          targetEnd.isAfter(chartStart);
    }).toList();

    final preActivityMeals = treatments.whereType<Meal>().where((meal) {
      final createdAt = meal.createdAt;
      if (createdAt == null) return false;
      return _isBetween(createdAt, preMealStart, log.startedAt);
    }).toList();

    final previousMeals = !includeContext
        ? <MealData>[]
        : await ref
              .read(databaseProvider)
              .mealDao
              .getCompletedMealsByRecordedTime(preMealStart, log.startedAt);
    final latestMeal = previousMeals.lastOrNull;
    final lastMeal = latestMeal == null
        ? null
        : await ref.read(loadMealDetailsUseCaseProvider).call(latestMeal.id);

    final postActivityMeals = <MealDetailsData>[];
    if (includeContext) {
      final meals = await ref
          .read(databaseProvider)
          .mealDao
          .getCompletedMealsByRecordedTime(activityEnd, chartEnd);
      for (final meal in meals) {
        if (!const {
          'eaten',
          'eaten-extra',
          'eaten-bolused',
          'summarized',
        }.contains(meal.status)) {
          continue;
        }
        final details = await ref
            .read(loadMealDetailsUseCaseProvider)
            .call(meal.id);
        if (details.analysisTime.isAfter(activityEnd) &&
            !details.analysisTime.isAfter(chartEnd)) {
          postActivityMeals.add(details);
        }
      }
      postActivityMeals.sort(
        (a, b) => a.analysisTime.compareTo(b.analysisTime),
      );
    }

    return ActivityLogAnalysisData(
      chartStart: chartStart,
      chartEnd: chartEnd,
      activityStart: log.startedAt,
      activityEnd: activityEnd,
      glucoseReadings: glucose,
      deviceStatuses: deviceStatuses,
      chartTreatments: chartTreatments,
      activityTargets: activityTargets,
      preActivityMeals: preActivityMeals,
      deviceStatusAtStart: deviceStatusAtStart,
      lastMeal: lastMeal,
      postActivityMeals: postActivityMeals,
    );
  }

  bool _isBetween(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }
}
