import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/model/ingredient.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';

part 'template_meal_draft.freezed.dart';

@freezed
abstract class MealTemplateIngredientsDraft with _$MealTemplateIngredientsDraft {
  const factory MealTemplateIngredientsDraft({
    required Ingredient ingredient,
    required IngredientPortionDraft ingredientPortion,
    required double defaultAmount,
    required bool isOptional,
    required double quantityConfidence,
    required String prepMethod,
    required String notes,
  }) = _MealTemplateIngredientsDraft;
}

@freezed
abstract class MealTemplateDraft with _$MealTemplateDraft {
  const factory MealTemplateDraft({
    required String name,
    required List<MealTemplateIngredientsDraft> mealIngredients,
    String? notes,
    required bool isFavorite,
    int? createdFromMealId,
  }) = _MealTemplateDraft;
}
