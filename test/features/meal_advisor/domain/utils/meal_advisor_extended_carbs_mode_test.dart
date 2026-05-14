import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MealAdvisor currently always suggests extended carbs delivery', () {
    final advisor = MealAdvisor(
      config: const MealAdvisorConfig(
        extendedCarbsScheduleSettings: ExtendedCarbsScheduleSettings(
          deliveryMode: ExtendedCarbsDeliveryMode.extraBolus,
          delayMinutes: 30,
          durationMinutes: 90,
        ),
      ),
    );

    final advice = advisor.getMealAdvice(
      bg: 120,
      iob: 0,
      cob: 0,
      trend: 0,
      mealCarbs: 40,
      fatGrams: 20,
      proteinGrams: 10,
      fiberGrams: 0,
    );

    expect(
      advice.extendedCarbs.scheduleSettings.deliveryMode,
      ExtendedCarbsDeliveryMode.extendedCarbs,
    );
    expect(advice.extendedCarbs.scheduleSettings.delayMinutes, 30);
    expect(advice.extendedCarbs.scheduleSettings.durationMinutes, 90);
  });

  test('post-meal extended carbs schedule currently comes from settings', () {
    final advisor = MealAdvisor(
      config: const MealAdvisorConfig(
        extendedCarbsScheduleSettings: ExtendedCarbsScheduleSettings(
          deliveryMode: ExtendedCarbsDeliveryMode.extraBolus,
          delayMinutes: 35,
          durationMinutes: 150,
        ),
      ),
    );

    final settings = advisor.getPostMealExtendedCarbsScheduleSettings();

    expect(settings.deliveryMode, ExtendedCarbsDeliveryMode.extendedCarbs);
    expect(settings.delayMinutes, 35);
    expect(settings.durationMinutes, 150);
  });
}
