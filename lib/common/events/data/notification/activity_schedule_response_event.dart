import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../foreground/event/model/foreground_event.dart';
import '../notification_event_data.dart';

part 'activity_schedule_response_event.freezed.dart';
part 'activity_schedule_response_event.g.dart';

@Freezed(unionKey: 'action', unionValueCase: FreezedUnionCase.snake)
sealed class ActivityScheduleResponseEvent
    with _$ActivityScheduleResponseEvent, NotificationEventData
    implements ForegroundEvent {
  const ActivityScheduleResponseEvent._();
  const factory ActivityScheduleResponseEvent.agree({
    required int occurrenceId,
    int? expectedStartedAt,
    int? expectedRevision,
  }) = ActivityScheduleAgree;
  const factory ActivityScheduleResponseEvent.skip({
    required int occurrenceId,
    int? expectedStartedAt,
    int? expectedRevision,
  }) = ActivityScheduleSkip;
  const factory ActivityScheduleResponseEvent.empty({
    required int occurrenceId,
    int? expectedStartedAt,
    int? expectedRevision,
  }) = ActivityScheduleOpen;
  factory ActivityScheduleResponseEvent.fromJson(Map<String, dynamic> json) =>
      _$ActivityScheduleResponseEventFromJson(json);
  @override
  String get eventName => 'activity_schedule_response';
}
