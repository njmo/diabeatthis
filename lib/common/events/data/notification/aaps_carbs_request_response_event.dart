import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../foreground/event/model/foreground_event.dart';
import '../notification_event_data.dart';

part 'aaps_carbs_request_response_event.freezed.dart';
part 'aaps_carbs_request_response_event.g.dart';

@Freezed(unionKey: 'action', unionValueCase: FreezedUnionCase.snake)
sealed class AapsCarbsRequestResponseEvent
    with _$AapsCarbsRequestResponseEvent, NotificationEventData
    implements ForegroundEvent {
  const AapsCarbsRequestResponseEvent._();

  const factory AapsCarbsRequestResponseEvent.agree({
    required String episodeId,
  }) = _AapsCarbsRequestAgreeEvent;

  const factory AapsCarbsRequestResponseEvent.empty({
    required String episodeId,
  }) = _AapsCarbsRequestEmptyEvent;

  factory AapsCarbsRequestResponseEvent.fromJson(Map<String, dynamic> json) =>
      _$AapsCarbsRequestResponseEventFromJson(json);

  @override
  String get eventName => 'aaps_carbs_request_response';
}
