import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../foreground/event/model/foreground_event.dart';
import '../notification_event_data.dart';

part 'meal_suggestion_response_event.freezed.dart';
part 'meal_suggestion_response_event.g.dart';

@Freezed(unionKey: 'action', unionValueCase: FreezedUnionCase.snake)
sealed class MealSuggestionResponseEvent
    with _$MealSuggestionResponseEvent, NotificationEventData implements ForegroundEvent {
  const MealSuggestionResponseEvent._();

  const factory MealSuggestionResponseEvent.agree({
    required int mealId,
  }) = _MealSuggestionResponseAgreeEvent;

  const factory MealSuggestionResponseEvent.skip({
    required int mealId,
  }) = _MealSuggestionResponseSkipEvent;

  const factory MealSuggestionResponseEvent.snooze({
    required int mealId,
    required String input,
  }) = _MealSuggestionResponseSnoozeEvent;

  const factory MealSuggestionResponseEvent.empty({
    required int mealId,
  }) = _MealSuggestionResponseEmptyEvent;

  factory MealSuggestionResponseEvent.fromJson(Map<String, dynamic> json) =>
      _$MealSuggestionResponseEventFromJson(json);

  @override
  String get eventName => 'meal_suggestion_response';
}
