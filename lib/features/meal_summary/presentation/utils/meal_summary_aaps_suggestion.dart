import '../../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../../meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'meal_summary_carbs_delta.dart';

bool shouldOpenAapsForMealSummaryAapsCarbs(MealSummaryAapsCarbs aapsCarbs) {
  return aapsCarbs.carbs != 0 || aapsCarbs.extendedCarbs > 0;
}

AapsBolusSuggestionNotificationEvent? buildMealSummaryAapsSuggestionEvent({
  required MealSummaryAapsCarbs aapsCarbs,
  required ExtendedCarbsScheduleSettings? extendedCarbsScheduleSettings,
}) {
  if (!shouldOpenAapsForMealSummaryAapsCarbs(aapsCarbs)) {
    return null;
  }

  return AapsBolusSuggestionNotificationEvent(
    carbs: aapsCarbs.carbs,
    extendedCarbs: aapsCarbs.extendedCarbs,
    extendedCarbsDeliveryMode: extendedCarbsScheduleSettings?.deliveryMode,
    extendedCarbsDelayMinutes: extendedCarbsScheduleSettings?.delayMinutes,
    extendedCarbsDurationMinutes:
        extendedCarbsScheduleSettings?.durationMinutes,
  );
}
