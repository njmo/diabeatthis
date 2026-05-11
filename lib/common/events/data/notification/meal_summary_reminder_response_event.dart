import 'package:freezed_annotation/freezed_annotation.dart';

import '../notification_event_data.dart';

part 'meal_summary_reminder_response_event.freezed.dart';
part 'meal_summary_reminder_response_event.g.dart';

@Freezed(unionKey: 'action', unionValueCase: FreezedUnionCase.snake)
sealed class MealSummaryReminderResponseEvent
    with _$MealSummaryReminderResponseEvent, NotificationEventData {
  const MealSummaryReminderResponseEvent._();

  const factory MealSummaryReminderResponseEvent.agree({required int mealId}) =
      _MealSummaryReminderResponseAgreeEvent;

  const factory MealSummaryReminderResponseEvent.empty({required int mealId}) =
      _MealSummaryReminderResponseEmptyEvent;

  factory MealSummaryReminderResponseEvent.fromJson(
    Map<String, dynamic> json,
  ) => _$MealSummaryReminderResponseEventFromJson(json);

  @override
  String get eventName => 'meal_summary_reminder_response';
}
