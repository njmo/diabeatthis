import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_log.freezed.dart';

@freezed
abstract class ActivityLog with _$ActivityLog {
  const factory ActivityLog({
    required int id,
    required int activityId,
    required DateTime startedAt,
    required DateTime? endedAt,
  }) = _ActivityLog;
}
