import '../../../../common/l10n/language.dart';

export '../../domain/utils/meal_add_on_status.dart';

class MealAddOnGuidance {
  const MealAddOnGuidance({required this.title, required this.message});

  final String title;
  final String message;
}

MealAddOnGuidance buildMealAddOnGuidance({
  required String? currentMealStatus,
  required int addedCarbs,
  required int? totalCarbsForBolus,
}) {
  if (currentMealStatus == 'eating-then-bolus' && totalCarbsForBolus != null) {
    return MealAddOnGuidance(
      title: lang.mealAddOnGuidanceTotalTitle(totalCarbsForBolus),
      message: lang.mealAddOnGuidanceTotalMessage(
        addedCarbs,
        totalCarbsForBolus,
      ),
    );
  }

  return MealAddOnGuidance(
    title: lang.mealAddOnGuidanceAddedTitle(addedCarbs),
    message: lang.mealAddOnGuidanceAddedMessage(addedCarbs),
  );
}
