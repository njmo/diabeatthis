import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../foreground/event/model/foreground_event.dart';
import '../notification_event_data.dart';

part 'eat_now_response_event.freezed.dart';
part 'eat_now_response_event.g.dart';

@Freezed(unionKey: 'action', unionValueCase: FreezedUnionCase.snake)
sealed class EatNowResponseEvent
    with _$EatNowResponseEvent, NotificationEventData implements ForegroundEvent {
  const EatNowResponseEvent._();

  const factory EatNowResponseEvent.eating({
    required int mealId,
  }) = _EatNowResponseEatingEvent;

  const factory EatNowResponseEvent.dismiss({
    required int mealId,
  }) = _EatNowResponseDismissEvent;

  const factory EatNowResponseEvent.empty({
    required int mealId,
  }) = _EatNowResponseEmptyEvent;

  factory EatNowResponseEvent.fromJson(Map<String, dynamic> json) =>
      _$EatNowResponseEventFromJson(json);

  @override
  String get eventName => 'eat_now_response';
}
