import 'package:freezed_annotation/freezed_annotation.dart';

import '../model/foreground_event.dart';

part 'activity_event.freezed.dart';
part 'activity_event.g.dart';

@Freezed(unionKey: 'kind', unionValueCase: FreezedUnionCase.kebab)
sealed class ActivityEvent with _$ActivityEvent implements ForegroundEvent {
  const ActivityEvent._();

  const factory ActivityEvent.next({
    required int activityLogId,
    required int activityId,
    required DateTime startsAt,
  }) = NextActivityEvent;

  const factory ActivityEvent.started({
    required int activityLogId,
    required int activityId,
    required DateTime startsAt,
  }) = ActivityStartedEvent;

  const factory ActivityEvent.stopped({
    required int activityLogId,
    required int activityId,
    required DateTime startsAt,
    required DateTime stoppedAt,
  }) = ActivityStoppedEvent;

  const factory ActivityEvent.cancelled({
    required int activityLogId,
    required int activityId,
    required DateTime startsAt,
  }) = ActivityCancelledEvent;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) =>
      _$ActivityEventFromJson(json);
}
