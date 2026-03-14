import 'package:freezed_annotation/freezed_annotation.dart';

import '../model/foreground_event.dart';

part 'meal_status_changed_event.freezed.dart';
part 'meal_status_changed_event.g.dart';

@Freezed(
  unionKey: 'kind',
  unionValueCase: FreezedUnionCase.kebab,
)
sealed class MealStatusChangedEvent with _$MealStatusChangedEvent implements ForegroundEvent {
  const MealStatusChangedEvent._();

  const factory MealStatusChangedEvent.eating({
    required int mealId,
  }) = MealStartedEatingEvent;

  const factory MealStatusChangedEvent.eaten({
    required int mealId,
  }) = MealFinishedEatingEvent;

  const factory MealStatusChangedEvent.skipped({
    required int mealId,
  }) = MealSkippedEvent;

  const factory MealStatusChangedEvent.eatingThenBolus({
    required int mealId,
  }) = MealEatingThenBolus;

  const factory MealStatusChangedEvent.bolusedWaiting({
    required int mealId,
  }) = MealBolusedWaitingEvent;

  const factory MealStatusChangedEvent.bolusedEating({
    required int mealId,
  }) = MealBolusedEatingEvent;

  const factory MealStatusChangedEvent.eatenBolused({
    required int mealId,
  }) = MealFinishedEatingBolusedEvent;


  factory MealStatusChangedEvent.fromJson(Map<String, dynamic> json) =>
      _$MealStatusChangedEventFromJson(json);
}
