import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../foreground/event/model/foreground_event.dart';
import '../notification_event_data.dart';

part 'finished_eating_response_event.freezed.dart';
part 'finished_eating_response_event.g.dart';

@Freezed(unionKey: 'action', unionValueCase: FreezedUnionCase.snake)
sealed class FinishedEatingResponseEvent
    with _$FinishedEatingResponseEvent, NotificationEventData implements ForegroundEvent {
  const FinishedEatingResponseEvent._();

  const factory FinishedEatingResponseEvent.agree({
    required int mealId,
  }) = _FinishedEatingResponseEatingEvent;

  const factory FinishedEatingResponseEvent.snooze({
    required int mealId,
  }) = _FinishedEatingResponseSnoozeEvent;

  const factory FinishedEatingResponseEvent.empty({
    required int mealId,
  }) = _FinishedEatingResponseEmptyEvent;

  factory FinishedEatingResponseEvent.fromJson(Map<String, dynamic> json) =>
      _$FinishedEatingResponseEventFromJson(json);

  @override
  String get eventName => 'finished_eating_response';
}
