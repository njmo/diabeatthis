import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../common/events/data/notification/eat_now_response_event.dart';
import '../../../../common/events/data/notification/finished_eating_response_event.dart';
import '../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../common/events/data/notification/meal_summary_reminder_response_event.dart';
import '../../../../common/events/data/notification/temp_target_response_event.dart';

part 'notification_response_event.freezed.dart';
part 'notification_response_event.g.dart';

@Freezed(
  unionKey: 'notification_response_event',
  unionValueCase: FreezedUnionCase.snake,
)
sealed class NotificationResponseEvent with _$NotificationResponseEvent {
  const NotificationResponseEvent._();

  const factory NotificationResponseEvent.eatNowResponse({
    required EatNowResponseEvent data,
  }) = NotificationEatNowResponseEvent;

  const factory NotificationResponseEvent.tempTargetResponse({
    required TempTargetResponseEvent data,
  }) = NotificationTempTargetResponseEvent;

  const factory NotificationResponseEvent.mealSuggestionResponse({
    required MealSuggestionResponseEvent data,
  }) = NotificationMealSuggestionResponseEvent;

  const factory NotificationResponseEvent.mealSummaryReminderResponse({
    required MealSummaryReminderResponseEvent data,
  }) = NotificationMealSummaryReminderResponseEvent;

  const factory NotificationResponseEvent.finishedEatingResponse({
    required FinishedEatingResponseEvent data,
  }) = NotificationFinishedEatingResponseEvent;

  factory NotificationResponseEvent.fromJson(Map<String, dynamic> json) =>
      _$NotificationResponseEventFromJson(json);
}
