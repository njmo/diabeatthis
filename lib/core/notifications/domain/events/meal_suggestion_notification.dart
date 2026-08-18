import '../../../../common/l10n/language.dart';
import '../../../../features/dashboard/data/utils/meal_advisor.dart';
import '../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class MealSuggestionNotificationEvent implements NotificationEvent {
  MealSuggestionNotificationEvent({
    required this.mealId,
    required this.minutes,
    required this.decision,
    required this.carbs,
    this.extendedCarbs = 0,
    this.extendedCarbsDeliveryMode = ExtendedCarbsDeliveryMode.extendedCarbs,
    this.extendedCarbsDelayMinutes = 45,
    this.extendedCarbsDurationMinutes = 120,
    this.isAddOn = false,
  });

  final int mealId;
  final MealDecision decision;
  final int minutes;
  final int carbs;
  final int extendedCarbs;
  final ExtendedCarbsDeliveryMode extendedCarbsDeliveryMode;
  final int extendedCarbsDelayMinutes;
  final int extendedCarbsDurationMinutes;
  final bool isAddOn;

  @override
  NotificationEventType get type => NotificationEventType.mealSuggestion;

  @override
  String get notificationResponseEvent => 'meal_suggestion_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => isAddOn
      ? lang.notificationMealSuggestionAddOnTitle
      : lang.notificationMealSuggestionTitle;

  @override
  String get body {
    if (isAddOn) {
      if (carbs > 0) {
        return lang.notificationMealSuggestionAddOnWithCarbs(carbs);
      }
      return lang.notificationMealSuggestionAddOnWithoutCarbs;
    }

    final extendedCarbsText = extendedCarbs > 0
        ? formatExtendedCarbsInstruction(
            extendedCarbs,
            settings: ExtendedCarbsScheduleSettings(
              deliveryMode: extendedCarbsDeliveryMode,
              delayMinutes: extendedCarbsDelayMinutes,
              durationMinutes: extendedCarbsDurationMinutes,
            ),
          )
        : '';

    switch (decision) {
      case MealDecision.eatNowBolusLater:
        return lang.notificationMealSuggestionEatNowBolusLater(
          extendedCarbsText,
        );
      case MealDecision.bolusAndEatNow:
        return lang.notificationMealSuggestionBolusAndEatNow(
          carbs,
          extendedCarbsText,
        );
      case MealDecision.bolusWaitThenEat:
        return lang.notificationMealSuggestionBolusWaitThenEat(
          carbs,
          minutes,
          extendedCarbsText,
        );
      case MealDecision.bolus:
        return lang.notificationMealSuggestionBolus(carbs, extendedCarbsText);
    }
  }

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'mealId': mealId},
  };

  @override
  Map<String, Object?> toJson() => {
    'mealId': mealId,
    'minutes': minutes,
    'carbs': carbs,
    'extendedCarbs': extendedCarbs,
    'extendedCarbsDeliveryMode': extendedCarbsDeliveryMode.name,
    'extendedCarbsDelayMinutes': extendedCarbsDelayMinutes,
    'extendedCarbsDurationMinutes': extendedCarbsDurationMinutes,
    'decision': decision.index,
    'isAddOn': isAddOn,
  };

  factory MealSuggestionNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return MealSuggestionNotificationEvent(
      mealId: json['mealId'] as int,
      minutes: json['minutes'] as int,
      carbs: json['carbs'] as int,
      extendedCarbs: json['extendedCarbs'] as int? ?? 0,
      extendedCarbsDeliveryMode: _deliveryModeFromJson(
        json['extendedCarbsDeliveryMode'] as String?,
      ),
      extendedCarbsDelayMinutes:
          json['extendedCarbsDelayMinutes'] as int? ?? 45,
      extendedCarbsDurationMinutes:
          json['extendedCarbsDurationMinutes'] as int? ?? 120,
      decision: MealDecision.values[json['decision'] as int],
      isAddOn: json['isAddOn'] as bool? ?? false,
    );
  }
}

ExtendedCarbsDeliveryMode _deliveryModeFromJson(String? value) {
  return ExtendedCarbsDeliveryMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ExtendedCarbsDeliveryMode.extendedCarbs,
  );
}
