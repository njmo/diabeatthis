import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/domain/model/temporary_target.dart';
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

  Future<ActivityLogAnalysisData?> call(ActivityLogDetailsData log) async {
    final activityEnd = log.endedAt;
    if (activityEnd == null) {
      return null;
    }

    final chartStart = log.startedAt.subtract(const Duration(minutes: 30));
    final chartEnd = activityEnd.add(const Duration(minutes: 30));
    final treatmentFetchStart = chartStart.subtract(const Duration(hours: 4));
    final preMealStart = log.startedAt.subtract(const Duration(hours: 1));

    final repository = await ref.read(nightscoutRepositoryProvider.future);
    final glucose = await repository.fetchGlucoseBetween(chartStart, chartEnd);
    final treatments = await repository.fetchTreatmentsBetween(
      treatmentFetchStart,
      chartEnd,
    );
    final deviceStatuses = await repository.fetchDeviceStatusBetween(
      chartStart,
      chartEnd,
    );
    final deviceStatusAtStart = await repository.fetchLastDeviceStatusBefore(
      log.startedAt,
    );

    final chartTreatments = treatments.where((treatment) {
      final createdAt = treatment.createdAt;
      if (createdAt == null) return false;
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
    );
  }

  bool _isBetween(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }
}
