import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/device_status.dart';
import '../../../core/domain/model/meal.dart';
import '../../../features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import '../../../features/meal_advisor/data/providers/check_meal_advisor_device_status_use_case_provider.dart';
import '../../../features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import '../../../features/meal_advisor/data/providers/get_meal_activity_advice_use_case_provider.dart';
import '../../../features/meal_advisor/data/providers/get_meal_advice_use_case_provider.dart';
import '../../../features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import '../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../../../features/meals/data/providers/meal_ingredients_list_provider.dart';
import '../../meal/meal_decision.dart';
import '../meal_decision_answer.dart';

final captureMealAdvisorSuggestionProvider = Provider((ref) {
  Future<Map<String, Object?>?> capture(Meal meal, DeviceStatus? device) async {
    final check = ref.read(checkMealAdvisorDeviceStatusUseCaseProvider);
    if (device == null || check(device) != MealAdviceEligibility.available) {
      return null;
    }
    final eligibility = await ref.read(
      checkMealAdviceEligibilityUseCaseProvider,
    )();
    if (!ref.mounted || eligibility != MealAdviceEligibility.available) {
      return null;
    }
    final nutrition = await ref.read(
      mealMacronutrientsSummaryProvider(meal.id).future,
    );
    if (nutrition == null || !ref.mounted) return null;
    final activity = await ref.read(getMealActivityAdviceUseCaseProvider)(
      mealAt: meal.plannedAt,
    );
    if (!ref.mounted || check(device) != MealAdviceEligibility.available)
      return null;
    final advice = ref.read(getMealAdviceUseCaseProvider)(
      macros: nutrition,
      deviceStatus: device,
      settings:
          ref.read(extendedCarbsScheduleSettingsProvider).asData?.value ??
          const ExtendedCarbsScheduleSettings.defaults(),
      activityDoseSuggestion: activity,
    );
    final minutes = advice.wait?.recommendedMinutes;
    return switch (advice.decision) {
      MealDecision.eatNowBolusLater => {
        'type': MealDecisionAnswer.eatThenInsulin.name,
      },
      MealDecision.bolusAndEatNow => {
        'type': MealDecisionAnswer.insulinAndEat.name,
      },
      MealDecision.bolusWaitThenEat
          when minutes != null && minutes >= 1 && minutes <= 180 =>
        {'type': MealDecisionAnswer.insulinThenWait.name, 'minutes': minutes},
      _ => null,
    };
  }

  return (Meal meal, DeviceStatus? device) async {
    try {
      return await capture(
        meal,
        device,
      ).timeout(const Duration(milliseconds: 750));
    } catch (_) {
      // Optional context must never prevent the request from being sent.
      return null;
    }
  };
});
