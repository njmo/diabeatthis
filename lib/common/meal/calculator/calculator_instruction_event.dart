import '../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../core/notifications/domain/events/meal_suggestion_notification.dart';
import '../../../core/notifications/domain/models/notification_event.dart';

AapsBolusSuggestionNotificationEvent? calculatorInstructionEvent(
  NotificationEvent event,
) {
  if (event is AapsBolusSuggestionNotificationEvent) return event;
  if (event is! MealSuggestionNotificationEvent) return null;
  return AapsBolusSuggestionNotificationEvent(
    mealId: event.mealId,
    carbs: event.carbs,
    activityDoseSuggestion: event.activityDoseSuggestion,
    extendedCarbs: event.extendedCarbs,
    extendedCarbsAreAdditional: event.extendedCarbsAreAdditional,
    extendedCarbsDeliveryMode: event.extendedCarbsDeliveryMode,
    extendedCarbsDelayMinutes: event.extendedCarbsDelayMinutes,
    extendedCarbsDurationMinutes: event.extendedCarbsDurationMinutes,
  );
}
