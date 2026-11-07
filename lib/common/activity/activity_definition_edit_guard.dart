import 'activity_occurrence_preparation.dart';

/// Definitions are shared with meal advice. Keep the maximum supported advice
/// window stable while a nearby session can still use its percentages.
bool activityDefinitionLogBlocksEdit(int startedAt, int? endedAt, int now) =>
    startedAt <= now + const Duration(days: 1).inMilliseconds &&
    (endedAt == null ||
        endedAt >= now - const Duration(days: 1).inMilliseconds);

bool activityDefinitionOccurrenceBlocksEdit({
  required int startedAt,
  required String status,
  required int? targetRequestedAt,
  required int now,
}) =>
    activityOccurrencePreparationStarted(
      startedAt: startedAt,
      targetRequestedAt: targetRequestedAt,
      now: now,
    ) &&
    !['deleted', 'recorded'].contains(status) &&
    startedAt >= now - const Duration(days: 1).inMilliseconds;
