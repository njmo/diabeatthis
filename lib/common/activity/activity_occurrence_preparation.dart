import '../../features/activity/domain/activity_schedule_time.dart';

bool activityOccurrencePreparationStarted({
  required int startedAt,
  required int? targetRequestedAt,
  required int now,
}) =>
    targetRequestedAt != null &&
    startedAt <= now + activityPreparationLeadTime.inMilliseconds;
