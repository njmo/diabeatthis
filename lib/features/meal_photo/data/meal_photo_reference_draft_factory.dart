import '../../ingredients/data/drafts/ingredient_draft.dart';
import '../domain/models/meal_photo_review_item.dart';

class MealPhotoReferenceDraftFactory {
  const MealPhotoReferenceDraftFactory();
  IngredientDraft call(MealPhotoReviewItem item) {
    if (!item.referenceAccepted ||
        !item.validWeight ||
        item.referenceNutrition == null) {
      throw StateError(
        'Reference requires accepted whole-portion facts and physical grams',
      );
    }
    final facts = item.referenceNutrition!.scaled(100 / item.weightGrams!);
    facts.validate();
    return IngredientDraft.draft(
      name: item.displayName,
      carbsPer100g: facts.carbs,
      fiberPer100g: facts.fiber,
      fatPer100g: facts.fat,
      proteinPer100g: facts.protein,
      nutritionConfidence: item.nutritionConfidence,
      isReference: false,
      carbsLabelMode: facts.carbsLabelMode,
    );
  }
}
