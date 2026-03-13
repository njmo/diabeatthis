import 'package:freezed_annotation/freezed_annotation.dart';

import '../model/foreground_event.dart';

part 'meal_status_changed_event.freezed.dart';

@freezed
sealed class MealStatusChangedEvent with _$MealStatusChangedEvent implements ForegroundEvent {
  const MealStatusChangedEvent._();

  const factory MealStatusChangedEvent.startedEating({
    required int mealId,
  }) = MealStartedEatingEvent;

  const factory MealStatusChangedEvent.finishedEating({
    required int mealId,
  }) = MealFinishedEatingEvent;
}