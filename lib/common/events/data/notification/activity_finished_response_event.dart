import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../foreground/event/model/foreground_event.dart';
import '../notification_event_data.dart';

part 'activity_finished_response_event.freezed.dart';
part 'activity_finished_response_event.g.dart';

@Freezed(unionKey: 'action', unionValueCase: FreezedUnionCase.snake)
sealed class ActivityFinishedResponseEvent
    with _$ActivityFinishedResponseEvent, NotificationEventData
    implements ForegroundEvent {
  const ActivityFinishedResponseEvent._();

  const factory ActivityFinishedResponseEvent.agree({
    required int activityLogId,
  }) = _ActivityFinishedResponseAgreeEvent;

  const factory ActivityFinishedResponseEvent.dismiss({
    required int activityLogId,
  }) = _ActivityFinishedResponseDismissEvent;

  const factory ActivityFinishedResponseEvent.empty({
    required int activityLogId,
  }) = _ActivityFinishedResponseEmptyEvent;

  factory ActivityFinishedResponseEvent.fromJson(Map<String, dynamic> json) =>
      _$ActivityFinishedResponseEventFromJson(json);

  @override
  String get eventName => 'activity_finished_response';
}
