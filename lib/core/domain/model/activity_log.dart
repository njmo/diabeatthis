import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_log.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class ActivityLog with _$ActivityLog {
  const factory ActivityLog.existing({
    required int id,
    required int activityId,
    required DateTime startedAt,
    required DateTime? endedAt,
  }) = _ActivityLogExisting;

  const factory ActivityLog.draft({
    required int activityId,
    required DateTime startedAt,
  }) = _ActivityLogDraft;

  const factory ActivityLog.view({
    required int id,
    required String activityName,
    required int activityId,
    required DateTime startedAt,
    required DateTime? endedAt,
  }) = _ActivityLogView;
}
