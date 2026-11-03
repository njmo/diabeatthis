import '../../data/models/meal_details_data.dart';
import '../models/meal_origin_review.dart';

class BuildMealOriginUseCase {
  const BuildMealOriginUseCase();

  MealOriginReview? call(MealDetailsData details) {
    if (details.meal.basedOnMealId == null &&
        details.meal.mealTemplateId == null &&
        details.copyUsages.isEmpty) {
      return null;
    }
    return MealOriginReview(
      sourceId: details.meal.basedOnMealId,
      source: details.copySource,
      templateId: details.meal.mealTemplateId,
      usages: List.unmodifiable(details.copyUsages),
    );
  }
}
